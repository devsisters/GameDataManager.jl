using Localizer
using JSON
using Test

f = joinpath(@__DIR__, "test/data/testdata.json")

x = JSON.parsefile(f)