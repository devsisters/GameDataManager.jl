
function foo()
    repo = LibGit2.GitRepo(ENV["MARS-CLIENT"])

    LibGit2.need_update(repo)

end