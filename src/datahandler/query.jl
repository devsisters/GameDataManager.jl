"""
    query(d, args...)

DataFramesMeta의 @where 매크로를 호출할 때 검색어를 캐쉬로 생성해 둔다
같은 검색어를 입력하면 캐쉬에서 불러온다
"""

macro query(x, sheet, args...)
    println(args...)
    bt = esc(x)
    df = :($get(DataFrame, $bt, $sheet))
    :($(DataFramesMeta.where)($df, $(DataFramesMeta.with_anonymous(reduce(DataFramesMeta.and, args)))))
end