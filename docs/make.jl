using Documenter
using IRMA

makedocs(
    sitename = "IRMA",
    format = Documenter.HTML(),
    modules = [IRMA]
)

deploydocs(
    repo = "github.com/lyon-fnal/IRMA.jl.git",
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
