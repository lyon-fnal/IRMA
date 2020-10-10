using Documenter
using IRMA

makedocs(
    sitename = "IRMA",
    format = Documenter.HTML(),
    modules = [IRMA]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
