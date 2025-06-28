import os
import subprocess
import shutil
import fnmatch
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from typing import List

shall_not_delete: List[str] = []

langs = ['en', 'zh', 'cht']

iscc_path = r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'

srchelios_path = r'D:\dev\wows\SrcHelios\SrcHelios\res_mods'

forum_exclude_patterns = ['game_logo.svg', 'game_logo_alt.svg', 'game_logo_static.svg', 'game_logo_static_alt.svg', 'zzz_lk_ee_zjsj.mo', 'zzz_lk_ee_wws.mo']

min_include_patterns = ['version.info', 'global.mo']

lang_base_paths = {
    'en': r'D:\dev\wows\Korabli-LESTA-I18N-PublicTest',
    'zh': r'D:\dev\wows\Korabli-LESTA-L10N-PublicTest',
    'cht': r'D:\dev\wows\Korabli-L10n-CHT-PublicTest'
}

installer_name_pattern = {
    'zh': '澪刻汉化离线包-PT-$game_version$-$l10n_version$.exe',
    'cht': '澪刻繁體中文化離綫包-PT-$game_version$-$l10n_version$.exe',
    'en': 'LK-English-L10n-PT-$game_version$-$l10n_version$.exe'
}

def should_skip(path: Path, patterns: List[str]) -> bool:
    for pat in patterns:
        if fnmatch.fnmatch(path.name, pat) or fnmatch.fnmatch(str(path.relative_to(Path('.'))), pat):
            return True
    return False

def _collect_lang(lang_name: str, l10n_path: Path, ee_path: Path, locale_config_path: Path):
    print(f'正在收集{lang_name}语言的文件…')
    base_target_path = Path('Localizations').joinpath(lang_name)
    shutil.rmtree(base_target_path)
    os.makedirs(base_target_path, exist_ok=True)
    os.makedirs(base_target_path.joinpath('texts').joinpath('ru').joinpath('LC_MESSAGES'), exist_ok=True)
    for file in os.listdir(l10n_path):
        if 'version.info' in file or 'global.mo' in file:
            shutil.copy(l10n_path.joinpath(file), base_target_path.joinpath('texts').joinpath('ru').joinpath('LC_MESSAGES').joinpath(file))
    shutil.copytree(ee_path, base_target_path, dirs_exist_ok=True)
    shutil.copy(locale_config_path, base_target_path.joinpath('locale_config.xml'))

def collect_lang(lang_name: str, base_path: Path):
    _collect_lang(
        lang_name=lang_name,
        l10n_path=base_path.joinpath('Localizations').joinpath('latest'),
        ee_path=base_path.joinpath('BuiltInMods').joinpath('LKExperienceEnhancement'),
        locale_config_path=base_path.joinpath('Localizations').joinpath('locale_config.xml')
    )

def zip_lang(lang_name: str) -> str:
    lang_path = Path('Localizations').joinpath(lang_name)
    version_path = lang_path.joinpath('texts').joinpath('ru').joinpath('LC_MESSAGES').joinpath('version.info')
    with open(version_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        l10n_v = lines[0].strip() if len(lines) > 0 else ''
        game_v = lines[1].strip() if len(lines) > 1 else ''

    game_v_prefix = (game_v + '.') if game_v else ''
    dst_zip = f'Releases/{game_v_prefix}{l10n_v}.{lang_name}.pt.zip'
    print(f'正在生成压缩包：{dst_zip}')
    with ZipFile(dst_zip, 'w', ZIP_DEFLATED) as zf:
        for child in lang_path.rglob('*'):
            if child.is_dir():
                continue
            print(f'已包含文件：{child}')
            zf.write(child, os.path.join('res_mods', child.relative_to(lang_path)))
        zf.write(Path('Shared').joinpath('bin64').joinpath('paths.xml'), Path('bin64').joinpath('paths.xml'))
    shall_not_delete.append(dst_zip)
    return dst_zip

def pack_lang(lang_name: str) -> bool:
    lang_path = Path('Localizations').joinpath(lang_name)
    version_path = lang_path.joinpath('texts').joinpath('ru').joinpath('LC_MESSAGES').joinpath('version.info')

    with open(version_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        l10n_v = lines[0].strip() if len(lines) > 0 else ''
        game_v = lines[1].strip() if len(lines) > 1 else ''
    
    target_iss_file = f'lk_offline_installer_{lang_name}.iss'

    if not os.path.exists(target_iss_file):
        return False

    with open(target_iss_file, 'r', encoding='utf-8') as file:
        lines = file.readlines()

    with open(target_iss_file, 'w', encoding='utf-8') as file:
        for line in lines:
            if line.strip().startswith('AppVersion='):
                line = f'AppVersion={game_v}.{l10n_v}\n'
            file.write(line)
    print(f'正在生成{lang_name}语言的安装包…')
    result = subprocess.run([iscc_path, target_iss_file], capture_output=True, text=True)

    print("编译输出：")
    print(result.stdout)

    # Errors (if exist)
    if result.stderr:
        print("编译错误：")
        print(result.stderr)
        return False
    os.rename('Output/mysetup.exe', f'Output/{installer_name_pattern[lang_name].replace("$l10n_version$", l10n_v).replace("$game_version$", game_v)}')
    return True

def collect_shared():
    print('正在收集共享文件…')
    shared_dir = Path('Shared').joinpath('res_mods')
    shutil.rmtree(shared_dir)
    os.makedirs(shared_dir, exist_ok=True)
    shutil.copytree(srchelios_path, shared_dir, dirs_exist_ok=True)


if __name__ == '__main__':
    collect_shared()
    os.makedirs('Releases', exist_ok=True)
    for file in os.listdir('Output'):
        os.remove(f'Output/{file}')
    for lang in langs:
        try:
            # Full
            collect_lang(lang_name=lang, base_path=Path(lang_base_paths[lang]))
            print(f'已生成压缩包：{zip_lang(lang)}')
            pack = pack_lang(lang)
            if pack:
                print(f'已生成{lang}语言的安装包。')
            else:
                print(f'{lang}语言的安装包生成失败')
        except Exception as ex:
            print('异常：')
            print(ex)
    for file in os.listdir('Releases'):
        file = f'Releases/{file}'
        if not file.endswith('.zip'):
            continue
        if file not in shall_not_delete:
            os.remove(file)
            print(f'已删除压缩包：{file}')
    input('按回车键退出。')
