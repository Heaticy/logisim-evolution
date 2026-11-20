import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

REPO = 'Heaticy/logisim-evolution'
TAG = 'v5.0.0'
RELEASE_ID = 452281105
MSI = 'logisim-evolution-5.0.0-amd64.msi'
PORTABLE = 'logisim-evolution-5.0.0-windows-amd64.zip'
SUMS = 'SHA256SUMS'
NAMES = (MSI, PORTABLE, SUMS)
OLD_MSI = '04d143630607632072a2d7e4a34a55f75f0b26a268261cb843477efb1561148d'
OLD_PORTABLE = '6a8de7f9b330a513d3e37712e9a937ea1756a126d47d7fc921edd2d40d8bfbe6'
OLD_SUMS = 'af19b6cad9ca1fbb93893138dda347bc6820497ab21a7cb4910da61f00a7ec93'
BASE = f'repos/{REPO}/releases'

def gh(*args):
    return subprocess.check_output(['gh', *args], text=True, timeout=180)

def api(path, *args):
    return json.loads(gh('api', path, *args))

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def release():
    data = api(f'{BASE}/tags/{TAG}')
    assert data['id'] == RELEASE_ID and not data['draft'] and not data['immutable']
    return data

def asset_index(data):
    result = {a['name']: a for a in data['assets']}
    assert len(result) == len(data['assets'])
    return result

def rename(asset_id, name):
    result = api(f'{BASE}/assets/{asset_id}', '--method', 'PATCH', '-f', 'name='+name)
    assert result['id'] == asset_id and result['name'] == name

def download(name, folder):
    gh('release', 'download', TAG, '-R', REPO, '-p', name, '-D', str(folder))
    return folder / name

root = Path('.').resolve()
artifact = root/'windows-output'
transaction = root/'transaction'
backup = transaction/'backup'
staged = transaction/'staged'
verified = transaction/'verified'
for directory in (backup, staged, verified):
    directory.mkdir(parents=True, exist_ok=True)

previous_msi = artifact/'previous.msi'
candidate_msi = artifact/MSI
assert digest(previous_msi) == OLD_MSI
candidate = digest(candidate_msi)
assert candidate != OLD_MSI and candidate == (artifact/'msi.sha256').read_text().strip()
previous_portable = artifact/'previous-windows.zip'
candidate_portable = artifact/PORTABLE
assert digest(previous_portable) == OLD_PORTABLE
portable_hash = digest(candidate_portable)
assert portable_hash != OLD_PORTABLE and portable_hash == (artifact/'portable.sha256').read_text().strip()
original_release = release()
original = asset_index(original_release)
assert original[MSI]['digest'] == 'sha256:'+OLD_MSI
assert original[PORTABLE]['digest'] == 'sha256:'+OLD_PORTABLE
assert original[SUMS]['digest'] == 'sha256:'+OLD_SUMS
old_sums = download(SUMS, backup)
assert digest(old_sums) == OLD_SUMS
shutil.copyfile(previous_msi, backup/MSI)
shutil.copyfile(previous_portable, backup/PORTABLE)
(backup/'release.json').write_text(json.dumps(original_release, ensure_ascii=False, indent=2)+'\n')
before = old_sums.read_bytes()
new_sums = before
for name, old, new in ((MSI, OLD_MSI, candidate), (PORTABLE, OLD_PORTABLE, portable_hash)):
    original_line = (old + '  ' + name).encode()
    assert new_sums.count(original_line) == 1
    new_sums = new_sums.replace(original_line, (new + '  ' + name).encode(), 1)
for line in new_sums.decode().splitlines():
    checksum, name = line.split(maxsplit=1)
    expected = {MSI:candidate,PORTABLE:portable_hash}.get(name,original[name]['digest'].split(':')[1])
    assert checksum == expected

nonce = os.environ['GITHUB_RUN_ID'] + '-' + os.environ['GITHUB_RUN_ATTEMPT']
new_names = {name: f'candidate-{nonce}-{name}' for name in NAMES}
old_names = {name: f'backup-{nonce}-{name}' for name in NAMES}
assert not (set(new_names.values()) | set(old_names.values())) & set(original)
shutil.copyfile(candidate_msi, staged/new_names[MSI])
shutil.copyfile(candidate_portable, staged/new_names[PORTABLE])
(staged/new_names[SUMS]).write_bytes(new_sums)

gh('release','upload',TAG,'-R',REPO,*[str(staged/name) for name in new_names.values()])
with_staging = asset_index(release())
new_ids = {name: with_staging[staged_name]['id'] for name, staged_name in new_names.items()}
for name in NAMES:
    a = with_staging[new_names[name]]
    assert a['state'] == 'uploaded' and a['digest'] == 'sha256:'+digest(staged/new_names[name])
    assert a['size'] == (staged/new_names[name]).stat().st_size
    assert with_staging[name]['id']==original[name]['id']

try:
    for name in NAMES:
        rename(original[name]['id'], old_names[name])
        rename(new_ids[name], name)
    current = asset_index(release())
    for name in NAMES:
        a = current[name]
        assert a['id'] == new_ids[name] and a['digest'] == 'sha256:'+digest(staged/new_names[name])
        assert a['browser_download_url'] == f'https://github.com/{REPO}/releases/download/{TAG}/{name}'
    for name in set(original)-set(NAMES):
        assert current[name]['id'] == original[name]['id'] and current[name]['digest'] == original[name]['digest']
    assert download(SUMS, verified).read_bytes() == new_sums
except Exception:
    current_by_id = {a['id']:a['name'] for a in release()['assets']}
    for name in NAMES:
        if current_by_id.get(new_ids[name]) == name:
            rename(new_ids[name], new_names[name])
        if current_by_id.get(original[name]['id']) == old_names[name]:
            rename(original[name]['id'], name)
    print('Restored the original release filenames after a failed replacement.', flush=True)
    raise

for name in NAMES:
    gh('api', f'{BASE}/assets/{original[name]["id"]}', '--method', 'DELETE')
final = asset_index(release())
assert set(final) == set(original)
assert all(final[n]['id']==new_ids[n] for n in NAMES)
receipt = {'msi_sha256':candidate,'msi_asset_id':new_ids[MSI],
           'portable_sha256':portable_hash,'portable_asset_id':new_ids[PORTABLE],
           'previous_msi_sha256':OLD_MSI,'manifest_sha256':final[SUMS]['digest'],
           'build_commit':os.environ['BUILD_SHA'],'build_run':os.environ['BUILD_RUN']}
(verified/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt), flush=True)
tick = chr(96)
old_label = 'The MSI adds ' + tick + 'logisim-evolution' + tick + ' and ' + tick + 'logisim' + tick + ' to PATH.'
new_label = 'The MSI adds ' + tick + 'logisim-evolution' + tick + ' to PATH.'
body = (original_release.get('body') or '').replace(old_label,new_label)
body += (f"\n\n**Windows packaging update.** The MSI creates one desktop and one Start Menu shortcut. "
         f"The Windows MSI and portable ZIP expose only {tick}logisim-evolution{tick}. "
         f"[Build source](https://github.com/{REPO}/commit/{receipt['build_commit']}).\n")
subprocess.run(['gh','api',f'{BASE}/{RELEASE_ID}','--method','PATCH','--input','-','--silent'],
               input=json.dumps({'body':body}),text=True,check=True,timeout=60)

