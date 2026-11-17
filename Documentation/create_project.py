from pathlib import Path
import hashlib
import json
import math
import sys

root=Path(__file__).resolve().parent.parent

# Icon rendering is opt-in (`python3 Documentation/create_project.py --icons`) so regenerating the
# project never overwrites approved artwork and Pillow is only needed when re-rendering icons.
def render_icons():
    from PIL import Image, ImageDraw, ImageFilter
    assets=root/'App'/'Assets.xcassets'/'AppIcon.appiconset'
    assets.mkdir(parents=True,exist_ok=True)
    W=1024
    # Original 1024px vector-style rendering of HitFluence's metallic bracketed hashtag.
    # Replace with the owner's approved production mascot asset when it is available.
    base=Image.new('RGBA',(W,W),(0,0,0,0))
    d=ImageDraw.Draw(base)
    d.rounded_rectangle((12,12,W-12,W-12),radius=235,fill=(17,23,44,255))
    for radius,rgba in [(430,(47,107,255,16)),(310,(156,123,255,20)),(195,(242,179,61,19))]:
        layer=Image.new('RGBA',(W,W),(0,0,0,0)); ld=ImageDraw.Draw(layer)
        ld.ellipse((570-radius,340-radius,570+radius,340+radius),fill=rgba)
        base=Image.alpha_composite(base,layer)
    # Warm rim lighting, cut into the deep graphite tile.
    d=ImageDraw.Draw(base)
    d.rounded_rectangle((20,20,1004,1004),radius=221,outline=(109,125,194,125),width=4)
    # Oversized, beveled metallic gold mark with cool periwinkle glancing lights.
    mask=Image.new('L',(W,W),0)
    md=ImageDraw.Draw(mask)
    # Two angled uprights and two horizontal strokes.
    for line in [(428,300,346,715),(646,300,565,715),(300,430,730,430),(268,604,698,604)]:
        md.line(line,fill=255,width=72)
        for x,y in [(line[0],line[1]),(line[2],line[3])]:
            md.ellipse((x-36,y-36,x+36,y+36),fill=255)
    # The blue/lavender bloom is intentional and restrained.
    glow=Image.new('RGBA',(W,W),(0,0,0,0))
    glow_layer=Image.new('RGBA',(W,W),(99,88,255,0));glow_layer.putalpha(mask)
    glow=Image.alpha_composite(glow,glow_layer.filter(ImageFilter.GaussianBlur(36)))
    base=Image.alpha_composite(base,Image.blend(Image.new('RGBA',(W,W),(0,0,0,0)),glow,0.45))
    metal=Image.new('RGBA',(W,W),(0,0,0,0));pixels=metal.load()
    for y in range(W):
        for x in range(W):
            t=min(1,max(0,(0.75*x/W+0.9*y/W)))
            high=(255,224,145); low=(222,130,52)
            pixels[x,y]=(int(high[0]*(1-t)+low[0]*t),int(high[1]*(1-t)+low[1]*t),int(high[2]*(1-t)+low[2]*t),255)
    metal.putalpha(mask)
    base=Image.alpha_composite(base,metal)
    d=ImageDraw.Draw(base)
    # Thin bracket-shaped strokes echo the approved HitCode [#] identity.
    for pts in [[(253,278),(196,278),(196,738),(253,738)],[(753,278),(810,278),(810,738),(753,738)]]:
        d.line(pts,fill=(143,168,255,237),width=26,joint='curve')
        for x,y in [pts[0],pts[-1]]: d.ellipse((x-13,y-13,x+13,y+13),fill=(143,168,255,237))
    # Mint and coral constellation accents, used throughout HitFluence branding.
    d.ellipse((782,230,814,262),fill=(63,224,181,255))
    d.ellipse((199,796,224,821),fill=(255,122,89,255))
    base.save(assets/'AppIcon1024.png')
    # Use both macOS 1x and 2x slots, derived from high-res source
    names={16:'icon_16.png',32:'icon_32.png',64:'icon_64.png',128:'icon_128.png',256:'icon_256.png',512:'icon_512.png',1024:'AppIcon1024.png'}
    for side,name in names.items():
        if side!=1024: base.resize((side,side),Image.Resampling.LANCZOS).save(assets/name)
    entries=[]
    for logical in [16,32,128,256,512]:
        for scale in [1,2]:
            size=logical*scale
            entries.append({'size':f'{logical}x{logical}','idiom':'mac','filename':names[size],'scale':f'{scale}x'})
    (assets/'Contents.json').write_text(json.dumps({'images':entries,'info':{'author':'xcode','version':1}},indent=2)+'\n')
    (root/'App'/'Assets.xcassets'/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}})+'\n')
    return len(entries)

icon_count = render_icons() if '--icons' in sys.argv else None

app_paths=[p.relative_to(root) for p in sorted((root/'App').rglob('*.swift'))]
core_paths=[p.relative_to(root) for p in sorted((root/'Sources/PromptStudioCore').glob('*.swift'))]
unsupported=[p for p in app_paths if p.parent.as_posix() not in ('App','App/Views','App/Services')]
if unsupported:
    sys.exit('Swift files outside App/, App/Views or App/Services need a project group: '+', '.join(map(str,unsupported)))
sources=app_paths+core_paths

# Deterministic 24-character project object IDs.
def xid(name): return hashlib.sha1(name.encode()).hexdigest().upper()[:24]
def obj(label): return xid(label)
def quote(s): return '"'+str(s).replace('\\','\\\\').replace('"','\\"')+'"'
def refid(p): return obj('fileref:'+str(p))
def buildid(p): return obj('buildfile:'+str(p))
entries=[]
def add(item): entries.append(item)
project=obj('project')
main_group=obj('group:root')
app_group=obj('group:app')
views_group=obj('group:views')
services_group=obj('group:services')
core_group=obj('group:core')
products_group=obj('group:products')
target=obj('target:app')
product=obj('ref:app-product')
sources_phase=obj('phase:sources')
resources_phase=obj('phase:resources')
assets_ref=refid('App/Assets.xcassets')
assets_build=buildid('App/Assets.xcassets')
config_project=obj('config:list:project')
config_target=obj('config:list:target')
configs={t:{mode:obj(f'config:{t}:{mode}') for mode in ['Debug','Release']} for t in ['project','target']}

# Swift packages for in-app local inference (Core AI + MLX). Exact pins match HitSwap's Package.resolved,
# which runs these models on this Mac today.
packages=[
    ('coreai-models','https://github.com/apple/coreai-models.git','1.0.0',['CoreAILM']),
    ('mlx-swift-lm','https://github.com/ml-explore/mlx-swift-lm','3.32.3',['MLXLLM','MLXVLM','MLXLMCommon']),
    ('swift-transformers','https://github.com/huggingface/swift-transformers','1.3.5',['Tokenizers']),
]
frameworks_phase=obj('phase:frameworks')
bundle_model_phase=obj('phase:script:bundle-coreai-model')
def pkgid(name): return obj('package:'+name)
def productid(name): return obj('product:'+name)
def productbuildid(name): return obj('buildfile:product:'+name)
products=[(pkg,prod) for pkg,_,_,prods in packages for prod in prods]
product_dependency_list=' '.join(f'{productid(prod)} /* {prod} */,' for _,prod in products)
package_reference_list=' '.join(f'{pkgid(pkg)} /* XCRemoteSwiftPackageReference "{pkg}" */,' for pkg,_,_,_ in packages)

for p in sources:
    add(f'\t\t{buildid(p)} /* {p.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {refid(p)} /* {p.name} */; }};')
add(f'\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};')
for pkg,prod in products:
    add(f'\t\t{productbuildid(prod)} /* {prod} in Frameworks */ = {{isa = PBXBuildFile; productRef = {productid(prod)} /* {prod} */; }};')

refs=[]
for p in sources:
    refs.append(f'\t\t{refid(p)} /* {p.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(p.name)}; sourceTree = "<group>"; }};')
for filename,type_ in [('Info.plist','text.plist.xml'),('PromptStudio.entitlements','text.plist.entitlements')]:
    p='App/'+filename
    refs.append(f'\t\t{refid(p)} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {type_}; path = {quote(filename)}; sourceTree = "<group>"; }};')
refs.append(f'\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};')
refs.append(f'\t\t{product} /* PromptStudio.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = PromptStudio.app; sourceTree = BUILT_PRODUCTS_DIR; }};')

def ref_line(file, prefix=''):
    p=f'{prefix}/{file}' if prefix else file
    return f'\t\t\t\t{refid(p)} /* {file} */,'
def group_line(id,label,children,path=None,name=None):
    chunks='\n'.join(f'\t\t\t\t{child},' for child in children)
    suffix='\n'.join([f'\t\t\tpath = {quote(path)};' if path else '',f'\t\t\tname = {quote(name)};' if name else ''])
    suffix=(suffix+'\n') if suffix.strip() else ''
    return f'\t\t{id} /* {label} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{chunks}\n\t\t\t);\n{suffix}\t\t\tsourceTree = "<group>";\n\t\t}};'

app_children=[f'{refid("App/"+p)} /* {p} */' for p in ['PromptStudioApp.swift','StudioModel.swift','Brand.swift']]
app_children += [f'{views_group} /* Views */',f'{services_group} /* Services */',f'{assets_ref} /* Assets.xcassets */']
app_children += [f'{refid("App/"+p)} /* {p} */' for p in ['Info.plist','PromptStudio.entitlements']]
groups=[
 group_line(main_group,'Main', [f'{app_group} /* App */',f'{core_group} /* PromptStudioCore */',f'{products_group} /* Products */']),
 group_line(app_group,'App',app_children,path='App'),
 group_line(views_group,'Views',[f'{refid(p)} /* {p.name} */' for p in app_paths if p.parent.as_posix()=='App/Views'],path='Views'),
 group_line(services_group,'Services',[f'{refid(p)} /* {p.name} */' for p in app_paths if p.parent.as_posix()=='App/Services'],path='Services'),
 group_line(core_group,'PromptStudioCore',[f'{refid(p)} /* {p.name} */' for p in core_paths],path='Sources/PromptStudioCore'),
 group_line(products_group,'Products',[f'{product} /* PromptStudio.app */'],name='Products')
]

source_buildfiles='\n'.join(f'\t\t\t\t{buildid(p)} /* {p.name} in Sources */,' for p in sources)
phase_sources=f'''\t\t{sources_phase} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (\n{source_buildfiles}\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; }};'''
phase_resources=f'''\t\t{resources_phase} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (\n\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; }};'''
config_project_lines=[]
config_target_lines=[]
for mode in ['Debug','Release']:
    debug=mode=='Debug'
    projsettings={
        'ALWAYS_SEARCH_USER_PATHS':'NO','CLANG_ENABLE_MODULES':'YES','SDKROOT':'macosx',
        'MACOSX_DEPLOYMENT_TARGET':'27.0','SWIFT_VERSION':'6.0',
        'SWIFT_STRICT_CONCURRENCY':'complete','SWIFT_COMPILATION_MODE':'singlefile' if debug else 'wholemodule',
        'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if debug else '-O',
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if debug else '',
        'DEBUG_INFORMATION_FORMAT':'dwarf' if debug else 'dwarf-with-dsym',
        'ENABLE_TESTABILITY':'YES' if debug else 'NO',
    }
    targetsettings={
        'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','CODE_SIGN_ENTITLEMENTS':'App/PromptStudio.entitlements',
        'CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'1',
        'GENERATE_INFOPLIST_FILE':'NO','INFOPLIST_FILE':'App/Info.plist',
        'LS_APPLICATION_CATEGORY_TYPE':'public.app-category.productivity','MARKETING_VERSION':'1.0',
        'PRODUCT_BUNDLE_IDENTIFIER':'com.hitfluence.PromptStudio','PRODUCT_NAME':'PromptStudio',
        'SWIFT_VERSION':'6.0','SWIFT_STRICT_CONCURRENCY':'complete',
        'MACOSX_DEPLOYMENT_TARGET':'27.0','SDKROOT':'macosx',
        'ENABLE_HARDENED_RUNTIME':'YES','SWIFT_EMIT_LOC_STRINGS':'YES',
        'SUPPORTED_PLATFORMS':'macosx',
        'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks',
        # The model-bundling script reads ~/Models (outside the source tree).
        'ENABLE_USER_SCRIPT_SANDBOXING':'NO',
    }
    def format_config(cid,name,settings):
        lines='\n'.join(f'\t\t\t\t{k} = {quote(v)};' for k,v in sorted(settings.items()))
        return f'\t\t{cid} /* {name} */ = {{isa = XCBuildConfiguration; buildSettings = {{\n{lines}\n\t\t\t}}; name = {name}; }};'
    config_project_lines.append(format_config(configs['project'][mode],mode,projsettings))
    config_target_lines.append(format_config(configs['target'][mode],mode,targetsettings))

config_list_lines=[
 f'''\t\t{config_project} /* Build configuration list for PBXProject "PromptStudio" */ = {{isa = XCConfigurationList; buildConfigurations = ( {configs['project']['Debug']} /* Debug */, {configs['project']['Release']} /* Release */ ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};''',
 f'''\t\t{config_target} /* Build configuration list for PBXNativeTarget "PromptStudio" */ = {{isa = XCConfigurationList; buildConfigurations = ( {configs['target']['Debug']} /* Debug */, {configs['target']['Release']} /* Release */ ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};'''
]
proj=f'''\t\t{project} /* Project object */ = {{isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 2730; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 27.3; }}; }}; }}; buildConfigurationList = {config_project} /* Build configuration list for PBXProject "PromptStudio" */; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = ( en, Base ); mainGroup = {main_group}; packageReferences = ( {package_reference_list} ); productRefGroup = {products_group}; projectDirPath = ""; projectRoot = ""; targets = ( {target} /* PromptStudio */, ); }};'''

native=f'''\t\t{target} /* PromptStudio */ = {{isa = PBXNativeTarget; buildConfigurationList = {config_target} /* Build configuration list for PBXNativeTarget "PromptStudio" */; buildPhases = ( {sources_phase} /* Sources */, {frameworks_phase} /* Frameworks */, {resources_phase} /* Resources */, {bundle_model_phase} /* Bundle Core AI model */, ); buildRules = (); dependencies = (); name = PromptStudio; packageProductDependencies = ( {product_dependency_list} ); productName = PromptStudio; productReference = {product} /* PromptStudio.app */; productType = "com.apple.product-type.application"; }};'''

frameworks_files='\n'.join(f'\t\t\t\t{productbuildid(prod)} /* {prod} in Frameworks */,' for _,prod in products)
phase_frameworks=f'''\t\t{frameworks_phase} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (\n{frameworks_files}\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; }};'''
# Copies the Core AI Qwen3-1.7B export into the app so a local model works with no setup (as KEV ships it).
# Weights are never committed to git; set PROMPTSTUDIO_BUNDLED_MODEL to use another export.
bundle_script='''set -eu
SRC="${PROMPTSTUDIO_BUNDLED_MODEL:-$HOME/Models/CoreAI/qwen3-1.7b}"
DEST="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/Models/$(basename "$SRC")"
if [ -f "$SRC/metadata.json" ]; then
  mkdir -p "$(dirname "$DEST")"
  rsync -a --delete "$SRC/" "$DEST/"
  echo "Bundled Core AI model from $SRC"
else
  echo "warning: No Core AI model at $SRC. Building without a bundled local model."
fi
'''
phase_bundle_model=f'''\t\t{bundle_model_phase} /* Bundle Core AI model */ = {{isa = PBXShellScriptBuildPhase; alwaysOutOfDate = 1; buildActionMask = 2147483647; files = (); inputFileListPaths = (); inputPaths = (); name = "Bundle Core AI model"; outputFileListPaths = (); outputPaths = (); runOnlyForDeploymentPostprocessing = 0; shellPath = /bin/sh; shellScript = {quote(bundle_script).replace(chr(10), chr(92)+'n')}; showEnvVarsInLog = 0; }};'''
package_reference_lines='\n'.join(f'''\t\t{pkgid(pkg)} /* XCRemoteSwiftPackageReference "{pkg}" */ = {{isa = XCRemoteSwiftPackageReference; repositoryURL = {quote(url)}; requirement = {{ kind = exactVersion; version = {version}; }}; }};''' for pkg,url,version,_ in packages)
product_dependency_lines='\n'.join(f'''\t\t{productid(prod)} /* {prod} */ = {{isa = XCSwiftPackageProductDependency; package = {pkgid(pkg)} /* XCRemoteSwiftPackageReference "{pkg}" */; productName = {prod}; }};''' for pkg,prod in products)

pbx=f'''// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(entries)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(refs)}
/* End PBXFileReference section */

/* Begin PBXGroup section */
{chr(10).join(groups)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
{native}
/* End PBXNativeTarget section */

/* Begin PBXProject section */
{proj}
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{phase_resources}
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{phase_sources}
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
{chr(10).join(config_project_lines)}
{chr(10).join(config_target_lines)}
/* End XCBuildConfiguration section */

/* Begin PBXFrameworksBuildPhase section */
{phase_frameworks}
/* End PBXFrameworksBuildPhase section */

/* Begin PBXShellScriptBuildPhase section */
{phase_bundle_model}
/* End PBXShellScriptBuildPhase section */

/* Begin XCRemoteSwiftPackageReference section */
{package_reference_lines}
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
{product_dependency_lines}
/* End XCSwiftPackageProductDependency section */

/* Begin XCConfigurationList section */
{chr(10).join(config_list_lines)}
/* End XCConfigurationList section */
\t}};
\trootObject = {project} /* Project object */;
}}
'''
(root/'PromptStudio.xcodeproj'/'project.pbxproj').write_text(pbx)
scheme_dir=root/'PromptStudio.xcodeproj'/'xcshareddata'/'xcschemes'
scheme_dir.mkdir(parents=True,exist_ok=True)
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2730" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
<BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="PromptStudio.app" BlueprintName="PromptStudio" ReferencedContainer="container:PromptStudio.xcodeproj"/>
</BuildActionEntry>
</BuildActionEntries>
</BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
<BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="PromptStudio.app" BlueprintName="PromptStudio" ReferencedContainer="container:PromptStudio.xcodeproj"/></BuildableProductRunnable>
</LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(scheme_dir/'PromptStudio.xcscheme').write_text(scheme)
print('App Swift source files:',len(app_paths))
print('Core Swift source files:',len(core_paths))
print('PBX size:',len(pbx))
print('Icon assets:', icon_count if icon_count is not None else 'unchanged (pass --icons to re-render)')
