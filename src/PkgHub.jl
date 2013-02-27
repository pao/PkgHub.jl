module PkgHub

import JSON

function authorize(user::String)
    response = readall(`curl https://api.github.com/authorizations --user "$user" --data '{"scopes":["repo"],"note":"PkgHub.jl"}'`)
    authtoken = JSON.parse(response)["token"]
    run(`git config --global julia.github.token $authtoken`)
    run(`git config --global julia.github.user $user`)
end

token() = readchomp(`git config --global julia.github.token`)

# GET
function ghapi(endpoint::String)
    JSON.parse(readall(`curl https://api.github.com/$endpoint?access_token=$(token())`))
end
# POST
function ghapi(endpoint::String, payload::Dict)
    JSON.parse(readall(`curl https://api.github.com/$endpoint?access_token=$(token()) --data $(JSON.to_json(payload))`))
end

function ghrepoinfo(pkg::String)
    m = match(r"github.com[:/]([^/]*)/(.*).git", Pkg.get_origin(pkg))
    if m == nothing
        user, repo = nothing, nothing
    else
        user, repo = m.captures[1], m.captures[2]
    end
end

function new(pkg::String, repo::String, private::Bool)
    Pkg.new(pkg)
    create(pkg, repo, private)
end
new(pkg::String) = new(pkg, pkg*".jl", false)

function create(pkg::String, repo::String, private::Bool)
    payload = {
               "name" => repo,
               "private" => private,
               }
    origin_url = ghapi("user/repos", payload)["ssh_url"]
    cd(Pkg.dir(pkg)) do
        run(`git remote add origin $origin_url`)
    end
    Pkg.pkg_origin(pkg)
end
create(pkg::String) = create(pkg, pkg*".jl", false)

function fork(pkg::String)
    user, repo = ghrepoinfo(pkg)
    fork_url = ghapi("repos/$user/$repo/forks", Dict())["ssh_url"]
    cd(Pkg.dir(pkg)) do
        run(`git remote add mine $fork_url`)
    end
    # would updating origin in local METADATA be the right thing to do here?
end

end