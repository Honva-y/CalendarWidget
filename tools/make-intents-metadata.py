#!/usr/bin/env python3
"""生成 App Intents 元数据（Metadata.appintents）。

正常情况下由 Xcode 构建时自动生成；这里没有 Xcode，按 Xcode 的输出格式手写。
意图定义在 Sources/CalendarCore/MonthIntents.swift，增删或改名时同步修改 INTENTS。
用法：make-intents-metadata.py <输出目录>/Metadata.appintents
"""
import json
import os
import sys

MODULE = "CalendarCore"
TOOLS_VERSION = "16E6052g"

# (类型名, 标题)
INTENTS = [
    ("PreviousMonthIntent", "上个月"),
    ("NextMonthIntent", "下个月"),
    ("ThisMonthIntent", "回到本月"),
    ("IgnoreTapIntent", "日历"),
]


def mangled(type_name):
    return f"{len(MODULE)}{MODULE}{len(type_name)}{type_name}V"


def action(type_name, title):
    return {
        "identifier": type_name,
        "fullyQualifiedTypeName": f"{MODULE}.{type_name}",
        "mangledTypeName": mangled(type_name),
        "mangledTypeNameV2": mangled(type_name),
        "mangledTypeNameByBundleIdentifier": {},
        "mangledTypeNameByBundleIdentifierV2": {},
        "title": {"key": title, "alternatives": []},
        "descriptionMetadata": {"descriptionText": {"key": title, "alternatives": []}, "searchKeywords": []},
        "parameters": [],
        "presentationStyle": 0,
        "systemProtocols": [],
        "systemProtocolMetadata": [],
        "systemProtocolMetadataV2": [],
        "assistantDefinedSchemas": [],
        "assistantDefinedSchemaTraits": [],
        "authenticationPolicy": 0,
        "isAuthPolExplicit": False,
        "requiredCapabilities": [],
        "outputFlags": 0,
        "typeSpecificMetadata": [],
        "availabilityAnnotations": {"LNPlatformNameWildcard": {"introducedVersion": "*"}},
        "visibilityMetadata": {"isDiscoverable": False, "assistantOnly": False},
        "effectiveBundleIdentifiers": [],
        "isDiscoverable": False,
        "openAppWhenRun": False,
    }


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    data = {
        "generator": {"name": "xcode-tools", "version": TOOLS_VERSION},
        "version": 1,
        "actions": {name: action(name, title) for name, title in INTENTS},
        "entities": {},
        "queries": {},
        "enums": [],
        "autoShortcuts": [],
        "assistantIntents": [],
        "assistantEntities": [],
        "negativePhrases": [],
        "assistantIntentNegativePhrases": [],
        "shortcutTileColor": 14,
    }
    with open(os.path.join(out, "extract.actionsdata"), "w") as f:
        json.dump(data, f, ensure_ascii=False)
    with open(os.path.join(out, "version.json"), "w") as f:
        json.dump({"version": "3.0", "toolsVersion": TOOLS_VERSION}, f, indent=2)


if __name__ == "__main__":
    main()
