using Test
using GameDataManager
using XLSXasJSON


using YAML


f1 = joinpath(@__DIR__, "YesNoPopup.prefab")
data = YAML.load(open(f1))

# 중간에 내용 바꾸는건 어떻게하지???
# IO 전체를 새로써야 하나...
f2 = joinpath(@__DIR__, "simple.prefab")
open(f2, "r+") do io
    for x in readlines(io)
        if startswith(x, "GameObject:")
                @show x
                replace(io, "testtt")
        end
    end
end



f1 = joinpath(@__DIR__, "BlockTemplateBalanceTable.asset")


f = begin
        x = read(f1, String)
        s1 = findfirst("--- !u!", x)
        s2 = findfirst("\r\n", x[s1.stop:end])
        x[s1.stop + s2.stop:end]
end

data = YAML.load(open(f))

s = """
GameObject:
  m_ObjectHideFlags: 1
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInternal: {fileID: 100100000}
  serializedVersion: 6
  m_Component:
  - component: {fileID: 224292076877367422}
  - component: {fileID: 222817843273353156}
  - component: {fileID: 114253144259944344}
  - component: {fileID: 114391172170757616}
  m_Layer: 5
  m_Name: YesButton
  m_TagString: Untagged
  m_Icon: {fileID: 0}
  m_NavMeshLayer: 0
  m_StaticEditorFlags: 0
  m_IsActive: 1
"""
data = YAML.load(s)


s2 = """
MonoBehaviour:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  m_GameObject: {fileID: 0}
  m_Enabled: 1
  m_EditorHideFlags: 0
  m_Script: {fileID: 11500000, guid: c0005b1b4a13413daa7460ecbdf42f13, type: 3}
  m_Name: BlockTemplateBalanceTable
  m_EditorClassIdentifier:
  _list:
  - Key: arche_4
    IsStructure: 1
    Size:
      X:
        _value: 4
      Z:
        _value: 4
      Y:
        _value: 4
"""
data = YAML.load(s2)
