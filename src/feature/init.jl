"""
        init_feature()
feature의 기능을 사용하기 위한 init
"""
function init_feature()
    # 사용할 데이터 테이블 메모리 로딩
    getgamedata("ItemTable"; parse = true)
    getgamedata("Residence"; parse = true)
    getgamedata("Shop"; parse = true)
    getgamedata("Special"; parse = true)
    getgamedata("Ability"; parse = true)



end
