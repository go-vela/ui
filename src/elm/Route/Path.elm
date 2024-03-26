{--
SPDX-License-Identifier: Apache-2.0
--}


module Route.Path exposing (Path(..), fromString, fromUrl, href, toString)

import Html
import Html.Attributes exposing (name)
import Url exposing (Url)
import Url.Parser exposing ((</>))


type Path
    = Home
    | AccountLogin
    | AccountLogout
    | AccountAuthenticate_
    | AccountSettings
    | AccountSourceRepos
    | Org_ { org : String }
    | Org_Builds { org : String }
    | Org_Repo_ { org : String, repo : String }
    | Org_Repo_Pulls { org : String, repo : String }
    | Org_Repo_Tags { org : String, repo : String }
    | Org_Repo_Deployments { org : String, repo : String }
    | Org_Repo_DeploymentsAdd { org : String, repo : String }
    | Org_Repo_Schedules { org : String, repo : String }
    | Org_Repo_SchedulesAdd { org : String, repo : String }
    | Org_Repo_SchedulesName_ { org : String, repo : String, name : String }
    | Org_Repo_Hooks { org : String, repo : String }
    | Org_Repo_Settings { org : String, repo : String }
    | Org_Repo_Build_ { org : String, repo : String, build : String }
    | Org_Repo_Build_Services { org : String, repo : String, build : String }
    | Org_Repo_Build_Pipeline { org : String, repo : String, build : String }
    | Org_Repo_Build_Graph { org : String, repo : String, build : String }
    | DashSecretsEngine_OrgOrg_ { engine : String, org : String }
    | DashSecretsEngine_OrgOrg_Add { engine : String, org : String }
    | DashSecretsEngine_OrgOrg_Name_ { engine : String, org : String, name : String }
    | DashSecretsEngine_RepoOrg_Repo_ { engine : String, org : String, repo : String }
    | DashSecretsEngine_RepoOrg_Repo_Add { engine : String, org : String, repo : String }
    | DashSecretsEngine_RepoOrg_Repo_Name_ { engine : String, org : String, repo : String, name : String }
    | DashSecretsEngine_SharedOrg_Team_ { engine : String, org : String, team : String }
    | DashSecretsEngine_SharedOrg_Team_Add { engine : String, org : String, team : String }
    | DashSecretsEngine_SharedOrg_Team_Name_ { engine : String, org : String, team : String, name : String }
    | NotFound_


fromUrl : Url -> Path
fromUrl url =
    fromString url.path
        |> Maybe.withDefault NotFound_


fromString : String -> Maybe Path
fromString urlPath =
    let
        urlPathSegments : List String
        urlPathSegments =
            urlPath
                |> String.split "/"
                |> List.filter (String.trim >> String.isEmpty >> Basics.not)
    in
    case urlPathSegments of
        [] ->
            Just Home

        [ "account", "login" ] ->
            Just AccountLogin

        [ "account", "logout" ] ->
            Just AccountLogout

        [ "account", "authenticate" ] ->
            Just AccountAuthenticate_

        [ "account", "settings" ] ->
            Just AccountSettings

        [ "account", "source-repos" ] ->
            Just AccountSourceRepos

        org :: [] ->
            Org_
                { org = org
                }
                |> Just

        org :: "builds" :: [] ->
            Org_Builds
                { org = org
                }
                |> Just

        org :: repo :: [] ->
            Org_Repo_
                { org = org
                , repo = repo
                }
                |> Just

        org :: repo :: "deployments" :: "add" :: [] ->
            Org_Repo_DeploymentsAdd
                { org = org
                , repo = repo
                }
                |> Just

        org :: repo :: "deployments" :: [] ->
            Org_Repo_Deployments
                { org = org
                , repo = repo
                }
                |> Just

        org :: repo :: "schedules" :: [] ->
            Org_Repo_Schedules
                { org = org
                , repo = repo
                }
                |> Just

        org :: repo :: "schedules" :: "add" :: [] ->
            Org_Repo_SchedulesAdd
                { org = org
                , repo = repo
                }
                |> Just

        org :: repo :: "schedules" :: name :: [] ->
            Org_Repo_SchedulesName_
                { org = org
                , repo = repo
                , name = name
                }
                |> Just

        org :: repo :: "hooks" :: [] ->
            Org_Repo_Hooks
                { org = org
                , repo = repo
                }
                |> Just

        org :: repo :: "settings" :: [] ->
            Org_Repo_Settings
                { org = org
                , repo = repo
                }
                |> Just

        org :: repo :: "pulls" :: [] ->
            Org_Repo_Pulls
                { org = org
                , repo = repo
                }
                |> Just

        org :: repo :: "tags" :: [] ->
            Org_Repo_Tags
                { org = org
                , repo = repo
                }
                |> Just

        org :: repo :: build :: [] ->
            Org_Repo_Build_
                { org = org
                , repo = repo
                , build = build
                }
                |> Just

        org :: repo :: build :: "services" :: [] ->
            Org_Repo_Build_Services
                { org = org
                , repo = repo
                , build = build
                }
                |> Just

        org :: repo :: build :: "pipeline" :: [] ->
            Org_Repo_Build_Pipeline
                { org = org
                , repo = repo
                , build = build
                }
                |> Just

        org :: repo :: build :: "graph" :: [] ->
            Org_Repo_Build_Graph
                { org = org
                , repo = repo
                , build = build
                }
                |> Just

        "-" :: "secrets" :: engine :: "org" :: org :: [] ->
            DashSecretsEngine_OrgOrg_
                { org = org
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "org" :: org :: "add" :: [] ->
            DashSecretsEngine_OrgOrg_Add
                { org = org
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "org" :: org :: name :: [] ->
            DashSecretsEngine_OrgOrg_Name_
                { org = org
                , name = name
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "repo" :: org :: repo :: [] ->
            DashSecretsEngine_RepoOrg_Repo_
                { org = org
                , repo = repo
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "repo" :: org :: repo :: "add" :: [] ->
            DashSecretsEngine_RepoOrg_Repo_Add
                { org = org
                , repo = repo
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "repo" :: org :: repo :: name :: [] ->
            DashSecretsEngine_RepoOrg_Repo_Name_
                { org = org
                , repo = repo
                , name = name
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "shared" :: org :: team :: [] ->
            DashSecretsEngine_SharedOrg_Team_
                { org = org
                , team = team
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "shared" :: org :: team :: "add" :: [] ->
            DashSecretsEngine_SharedOrg_Team_Add
                { org = org
                , team = team
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "shared" :: org :: team :: name :: [] ->
            DashSecretsEngine_SharedOrg_Team_Name_
                { org = org
                , team = team
                , name = name
                , engine = engine
                }
                |> Just

        _ ->
            Nothing


href : Path -> Html.Attribute msg
href path =
    Html.Attributes.href (toString path)


toString : Path -> String
toString path =
    let
        pieces : List String
        pieces =
            case path of
                Home ->
                    []

                AccountLogin ->
                    [ "account", "login" ]

                AccountLogout ->
                    [ "account", "logout" ]

                AccountAuthenticate_ ->
                    [ "account", "authenticate" ]

                AccountSettings ->
                    [ "account", "settings" ]

                AccountSourceRepos ->
                    [ "account", "source-repos" ]

                Org_ params ->
                    [ params.org ]

                Org_Builds params ->
                    [ params.org, "builds" ]

                Org_Repo_ params ->
                    [ params.org, params.repo ]

                Org_Repo_Pulls params ->
                    [ params.org, params.repo, "?event=pull_request" ]

                Org_Repo_Tags params ->
                    [ params.org, params.repo, "?event=tag" ]

                Org_Repo_Deployments params ->
                    [ params.org, params.repo, "deployments" ]

                Org_Repo_DeploymentsAdd params ->
                    [ params.org, params.repo, "deployments", "add" ]

                Org_Repo_Schedules params ->
                    [ params.org, params.repo, "schedules" ]

                Org_Repo_SchedulesAdd params ->
                    [ params.org, params.repo, "schedules", "add" ]

                Org_Repo_SchedulesName_ params ->
                    [ params.org, params.repo, "schedules", params.name ]

                Org_Repo_Hooks params ->
                    [ params.org, params.repo, "hooks" ]

                Org_Repo_Settings params ->
                    [ params.org, params.repo, "settings" ]

                Org_Repo_Build_ params ->
                    [ params.org, params.repo, params.build ]

                Org_Repo_Build_Services params ->
                    [ params.org, params.repo, params.build, "services" ]

                Org_Repo_Build_Pipeline params ->
                    [ params.org, params.repo, params.build, "pipeline" ]

                Org_Repo_Build_Graph params ->
                    [ params.org, params.repo, params.build, "graph" ]

                DashSecretsEngine_OrgOrg_ params ->
                    [ "-", "secrets", params.engine, "org", params.org ]

                DashSecretsEngine_OrgOrg_Add params ->
                    [ "-", "secrets", params.engine, "org", params.org, "add" ]

                DashSecretsEngine_OrgOrg_Name_ params ->
                    [ "-", "secrets", params.engine, "org", params.org, params.name ]

                DashSecretsEngine_RepoOrg_Repo_ params ->
                    [ "-", "secrets", params.engine, "repo", params.org, params.repo ]

                DashSecretsEngine_RepoOrg_Repo_Add params ->
                    [ "-", "secrets", params.engine, "repo", params.org, params.repo, "add" ]

                DashSecretsEngine_RepoOrg_Repo_Name_ params ->
                    [ "-", "secrets", params.engine, "repo", params.org, params.repo, params.name ]

                DashSecretsEngine_SharedOrg_Team_ params ->
                    [ "-", "secrets", params.engine, "shared", params.org, params.team ]

                DashSecretsEngine_SharedOrg_Team_Add params ->
                    [ "-", "secrets", params.engine, "shared", params.org, params.team, "add" ]

                DashSecretsEngine_SharedOrg_Team_Name_ params ->
                    [ "-", "secrets", params.engine, "shared", params.org, params.team, params.name ]

                NotFound_ ->
                    [ "not-found" ]
    in
    pieces
        |> String.join "/"
        |> String.append "/"
