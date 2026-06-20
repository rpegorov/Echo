//
//  NetworkMonitor.swift
//  MonitorBarApp
//

import Foundation

/// Монитор сетевой активности.
/// Использует sysctl(NET_RT_IFLIST2) с 64-битными счётчиками `if_data64` —
/// в отличие от getifaddrs (32-битный `if_data`), они не переполняются и не
/// дают «нулевых» провалов при высокой скорости. Скорость считается делением
/// дельты байт на реальный прошедший интервал, а не на условную «1 секунду».
actor NetworkMonitor: NetworkMonitoring {

    private var prevIn:   UInt64 = 0
    private var prevOut:  UInt64 = 0
    private var prevTime: Date?

    func speed() async -> NetworkMetrics {
        guard let counters = Self.readCounters() else { return NetworkMetrics() }
        let now = Date()

        defer {
            prevIn   = counters.inBytes
            prevOut  = counters.outBytes
            prevTime = now
        }

        // Первый замер — нет базы для дельты.
        guard let last = prevTime else { return NetworkMetrics() }
        let elapsed = now.timeIntervalSince(last)
        guard elapsed > 0 else { return NetworkMetrics() }

        // Защита от сброса счётчиков (реинициализация интерфейса).
        let deltaIn  = counters.inBytes  >= prevIn  ? counters.inBytes  - prevIn  : 0
        let deltaOut = counters.outBytes >= prevOut ? counters.outBytes - prevOut : 0

        let download = Double(deltaIn)  / 1024 / elapsed
        let upload   = Double(deltaOut) / 1024 / elapsed

        return NetworkMetrics(download: download, upload: upload)
    }

    // MARK: - Private

    /// Суммирует ibytes/obytes по всем не-loopback интерфейсам через таблицу маршрутизации.
    private static func readCounters() -> (inBytes: UInt64, outBytes: UInt64)? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]

        var length = 0
        guard sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) == 0, length > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, u_int(mib.count), &buffer, &length, nil, 0) == 0 else {
            return nil
        }

        var totalIn:  UInt64 = 0
        var totalOut: UInt64 = 0

        buffer.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < length {
                let header = base.advanced(by: offset)
                    .assumingMemoryBound(to: if_msghdr.self).pointee
                let messageLength = Int(header.ifm_msglen)
                guard messageLength > 0 else { break }

                if Int32(header.ifm_type) == RTM_IFINFO2 {
                    let info = base.advanced(by: offset)
                        .assumingMemoryBound(to: if_msghdr2.self).pointee
                    if (Int32(info.ifm_flags) & IFF_LOOPBACK) == 0 {
                        totalIn  += info.ifm_data.ifi_ibytes
                        totalOut += info.ifm_data.ifi_obytes
                    }
                }
                offset += messageLength
            }
        }

        return (totalIn, totalOut)
    }
}
