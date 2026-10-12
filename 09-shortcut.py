#!/usr/bin/env python3
"""Generate and HubSign a credential-free VPS-to-LLM shortcut template."""
import argparse
import json
from pathlib import Path
import plistlib
import uuid
import urllib.error
import urllib.request

SIGNER = 'https://hubsign.routinehub.services/sign'


def make_template():
    ssh_id = str(uuid.uuid4()).upper()
    result = {'WFSerializationType': 'WFTextTokenAttachment', 'Value': {
        'Type': 'ActionOutput', 'OutputUUID': ssh_id,
        'OutputName': 'Shell Script Result'}}
    def action(name, params):
        return {'WFWorkflowActionIdentifier': 'is.workflow.actions.' + name,
                'WFWorkflowActionParameters': params}
    questions = [
        {'ActionIndex': 0, 'Category': 'Parameter', 'ParameterKey': 'WFSSHHost',
         'Text': 'Your current VPS IP address or hostname', 'DefaultValue': ''},
        {'ActionIndex': 0, 'Category': 'Parameter', 'ParameterKey': 'WFSSHUser',
         'Text': 'VPS SSH username', 'DefaultValue': 'root'},
        {'ActionIndex': 0, 'Category': 'Parameter', 'ParameterKey': 'WFSSHPassword',
         'Text': 'Enter your SSH password locally, or leave blank and configure SSH Key in the shortcut editor.',
         'DefaultValue': ''},
    ]
    return {
        'WFWorkflowName': 'VPS to LLM',
        'WFWorkflowClientVersion': '3107.0.8.2',
        'WFWorkflowMinimumClientVersion': 900,
        'WFWorkflowMinimumClientVersionString': '900',
        'WFWorkflowIcon': {'WFWorkflowIconStartColor': 2071128575,
                           'WFWorkflowIconGlyphNumber': 59511},
        'WFWorkflowTypes': ['NCWidget'],
        'WFWorkflowInputContentItemClasses': ['WFStringContentItem'],
        'WFWorkflowImportQuestions': questions,
        'WFWorkflowActions': [
            action('runsshscript', {'UUID': ssh_id, 'WFSSHHost': '',
                   'WFSSHPort': '22', 'WFSSHUser': 'root',
                   'WFSSHAuthenticationType': 'Password', 'WFSSHPassword': '',
                   'WFSSHScript': '~/.local/bin/ocs last'}),
            action('setclipboard', {'WFInput': result, 'WFLocalOnly': True}),
            action('openapp', {'WFAppIdentifier': 'com.openai.chat',
                   'WFSelectedApp': {'BundleIdentifier': 'com.openai.chat',
                                     'Name': 'ChatGPT'}}),
        ],
    }


def sign(template):
    # Accept only this credential-free shape, never a user-configured shortcut.
    params = template['WFWorkflowActions'][0]['WFWorkflowActionParameters']
    assert params['WFSSHHost'] == '' and params['WFSSHPassword'] == ''
    xml = plistlib.dumps(template, fmt=plistlib.FMT_XML).decode()
    data = json.dumps({'shortcutName': 'VPS to LLM', 'shortcut': xml}).encode()
    request = urllib.request.Request(SIGNER, data=data, headers={
        'Content-Type': 'application/json', 'User-Agent': 'cherri/2.0.0 (compatible; ocs-shortcut/1.0)',
        'Origin': 'https://routinehub.co', 'Referer': 'https://routinehub.co/'},
        method='POST')
    with urllib.request.urlopen(request, timeout=45) as response:
        signed = response.read(8 * 1024 * 1024 + 1)
    if len(signed) > 8 * 1024 * 1024 or not signed.startswith(b'AEA1'):
        raise ValueError('Signing service did not return an AEA1 shortcut archive')
    return signed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', default='VPS-to-LLM.shortcut')
    parser.add_argument('--unsigned-only', action='store_true')
    args = parser.parse_args()
    target = Path(args.out).resolve()
    if target.exists():
        parser.error('Output already exists; choose another filename.')
    template = make_template()
    if args.unsigned_only:
        payload = plistlib.dumps(template, fmt=plistlib.FMT_BINARY)
        print('[1/2] Created unsigned template; iPhone import not yet available.', flush=True)
    else:
        print('[1/2] Signing template (no host, passwords or keys uploaded)...', flush=True)
        payload = sign(template)
    with target.open('xb') as output:
        output.write(payload)
    print(f'[2/2] Saved {target.name} ({len(payload)} bytes).', flush=True)
    print('iPhone import and execution require verification on the phone.', flush=True)


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        detail = error.read(1000).decode(errors='replace')
        raise SystemExit(f'[x] Signing failed: HTTP {error.code}: {detail}')
    except (OSError, ValueError, urllib.error.URLError) as error:
        raise SystemExit(f'[x] {error}')
