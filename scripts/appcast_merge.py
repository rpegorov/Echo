#!/usr/bin/env python3
"""Вставляет запись о новой версии в docs/appcast.xml.

Вызывается из scripts/appcast.sh; параметры приходят через переменные окружения:
VERSION, URL, SIGN (вывод sign_update), MIN_OS, NOTES, APPCAST.

Запись с той же версией заменяется — повторный прогон релиза не плодит дубли.
"""
import os
import re
from email.utils import formatdate
from xml.etree import ElementTree as ET

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)

SKELETON = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="{ns}">
  <channel>
    <title>Echo</title>
    <description>Обновления Echo</description>
    <language>ru</language>
  </channel>
</rss>
"""


def sparkle(tag):
    return f"{{{SPARKLE_NS}}}{tag}"


def main():
    version = os.environ["VERSION"]
    url = os.environ["URL"]
    sign_output = os.environ["SIGN"]
    min_os = os.environ.get("MIN_OS", "26.1")
    notes = os.environ.get("NOTES", "").strip()
    path = os.environ.get("APPCAST", "docs/appcast.xml")

    signature = re.search(r'sparkle:edSignature="([^"]+)"', sign_output)
    length = re.search(r'length="(\d+)"', sign_output)
    if not signature or not length:
        raise SystemExit(f"Не разобрал вывод sign_update: {sign_output!r}")

    os.makedirs(os.path.dirname(path), exist_ok=True)
    if not os.path.exists(path):
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(SKELETON.format(ns=SPARKLE_NS))

    tree = ET.parse(path)
    channel = tree.getroot().find("channel")

    for existing in channel.findall("item"):
        if (existing.findtext(sparkle("shortVersionString")) or "") == version:
            channel.remove(existing)

    item = ET.Element("item")
    ET.SubElement(item, "title").text = version
    ET.SubElement(item, "pubDate").text = formatdate(localtime=True)
    ET.SubElement(item, sparkle("version")).text = version
    ET.SubElement(item, sparkle("shortVersionString")).text = version
    ET.SubElement(item, sparkle("minimumSystemVersion")).text = min_os
    if notes:
        ET.SubElement(item, "description").text = notes
    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", url)
    enclosure.set("type", "application/octet-stream")
    enclosure.set("length", length.group(1))
    enclosure.set(sparkle("edSignature"), signature.group(1))

    # Новая версия — первой в ленте.
    channel.insert(len(list(channel)) - len(channel.findall("item")), item)

    ET.indent(tree, space="  ")
    tree.write(path, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    main()
