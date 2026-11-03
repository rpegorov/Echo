#!/usr/bin/env python3
"""Run affected test components, explicit release suites, or no tests for manual builds."""
import argparse
import fnmatch
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def output(command, cwd=ROOT):
    return subprocess.check_output(command, cwd=cwd, text=True, timeout=60)


def changed(base):
    if not base:
        event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text()) if os.getenv('GITHUB_EVENT_PATH') else {}
        base = (event.get('pull_request', {}).get('base', {}).get('sha') or event.get('before')
                or os.getenv('CI_MERGE_REQUEST_DIFF_BASE_SHA') or os.getenv('CI_COMMIT_BEFORE_SHA') or 'HEAD')
    if set(base) == {'0'}:
        raise ValueError('No comparison base; set TEST_BASE explicitly (no full-suite fallback)')
    output(['git', 'rev-parse', '--verify', base + '^{commit}'])
    files = output(['git', 'diff', '--name-only', '--no-renames', '-z', base, '--']).split('\0')
    files += output(['git', 'ls-files', '--others', '--exclude-standard', '-z']).split('\0')
    return base, {f for f in files if f}


def affected(files, patterns):
    return any(fnmatch.fnmatchcase(f, p) for f in files for p in patterns)


def dependents(selected, graph):
    while True:
        expanded = selected | {name for name, deps in graph.items() if selected.intersection(deps)}
        if expanded == selected:
            return selected
        selected = expanded


def native_targets(kind, cwd, files):
    relative = {os.path.relpath(ROOT / f, cwd) for f in files}
    if kind == 'swift':
        data = json.loads(output(['swift', 'package', 'describe', '--type', 'json'], cwd))
        nodes = data['targets']
        graph = {t['name']: t.get('target_dependencies', []) for t in nodes}
        chosen = {t['name'] for t in nodes if affected(relative, [t['path'] + '/*'])}
        if relative.intersection({'Package.swift', 'Package.resolved'}) or any(f.startswith('../') for f in relative):
            chosen = set(graph)
        chosen = dependents(chosen, graph)
        return ['--filter', '|'.join(sorted(t['name'] for t in nodes if t['type'] == 'test' and t['name'] in chosen))]
    if kind == 'cargo':
        data = json.loads(output(['cargo', 'metadata', '--locked', '--no-deps', '--format-version', '1'], cwd))
        nodes = [p for p in data['packages'] if p['id'] in data['workspace_members']]
        graph = {p['name']: [d['name'] for d in p['dependencies']] for p in nodes}
        chosen = set()
        for package in nodes:
            prefix = os.path.relpath(Path(package['manifest_path']).parent, cwd)
            if affected(relative, ['*' if prefix == '.' else prefix + '/*']):
                chosen.add(package['name'])
        if relative.intersection({'Cargo.toml', 'Cargo.lock', 'rust-toolchain.toml'}):
            chosen = set(graph)
        return [arg for name in sorted(dependents(chosen, graph)) for arg in ('-p', name)]
    raw = output(['go', 'list', '-mod=readonly', '-json', './...'], cwd)
    nodes, decoder = [], json.JSONDecoder()
    while raw.strip():
        node, end = decoder.raw_decode(raw.lstrip())
        nodes.append(node)
        raw = raw.lstrip()[end:]
    graph = {p['ImportPath']: p.get('Imports', []) + p.get('TestImports', []) + p.get('XTestImports', []) for p in nodes}
    chosen = {p['ImportPath'] for p in nodes if any((ROOT / f).parent == Path(p['Dir']) for f in files)}
    if relative.intersection({'go.mod', 'go.sum'}):
        chosen = set(graph)
    return sorted(dependents(chosen, graph))


def execute(command, cwd):
    child = subprocess.Popen(command, cwd=cwd, start_new_session=True)
    try:
        return child.wait(timeout=int(os.getenv('TEST_TIMEOUT', '900')))
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        os.killpg(child.pid, signal.SIGTERM)
        try:
            child.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('component', nargs='?', default='all')
    parser.add_argument('--mode', choices=['targeted', 'release', 'manual'], default=os.getenv('TEST_MODE') or 'targeted')
    parser.add_argument('--base', default=os.getenv('TEST_BASE'))
    parser.add_argument('--plan', action='store_true')
    parser.add_argument('--affected', action='store_true', help='Exit 0 only when this mode selects the component')
    args = parser.parse_args()
    if args.mode not in ('targeted', 'release', 'manual'):
        parser.error('Invalid TEST_MODE')
    if args.mode == 'manual':
        print('Tests not run — manual testing build; release verification pending.')
        return 1 if args.affected else 0
    config = json.loads((ROOT / '.test-policy.json').read_text())
    groups = config if args.component == 'all' else {args.component: config[args.component]}
    base, files = changed(args.base) if args.mode == 'targeted' else ('', set())
    for name, group in groups.items():
        cwd = ROOT / group.get('cwd', '.')
        if args.mode == 'targeted' and not affected(files, group['paths']):
            print('No affected tests:', name)
            continue
        if args.mode == 'targeted' and group.get('release_only'):
            print('Release-only suite:', name, '(run explicit scenario checks for this task)')
            continue
        if args.affected:
            return 0
        command = list(group['command'])
        kind = group.get('kind', 'component')
        if args.mode == 'targeted':
            if kind == 'vitest':
                command += ['--changed=' + base, '--passWithNoTests']
            elif kind in ('swift', 'cargo', 'go'):
                selected = native_targets(kind, cwd, {f for f in files if affected({f}, group['paths'])})
                if not selected or selected == ['--filter', '']:
                    print('No affected test targets:', name)
                    continue
                command += selected
        if args.mode == 'release':
            command += group.get('release_args', [])
        print(name + ': ' + shlex.join(command) + ' (cwd=' + str(cwd) + ')', flush=True)
        if not args.plan:
            result = execute(command, cwd)
            if result:
                return result
    return 1 if args.affected else 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print('Test selection/execution failed: ' + str(error), file=sys.stderr)
        raise SystemExit(2)
