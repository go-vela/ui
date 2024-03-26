{--
SPDX-License-Identifier: Apache-2.0
--}


module Route.Path exposing (Path(..), fromString, fromUrl, href, toString)

import Html
import Html.Attributes
import Url exposing (Url)
import Url.Parser exposing ((</>))


type Path
    = Home_
    | Account_Authenticate
    | Account_Login
    | Account_Logout
    | Account_Settings
    | Account_SourceRepos
    | Dash_Secrets_Engine__Org_Org_ { engine : String, org : String }
    | Dash_Secrets_Engine__Org_Org__Add { engine : String, org : String }
    | Dash_Secrets_Engine__Org_Org__Name_ { engine : String, org : String, name : String }
    | Dash_Secrets_Engine__Repo_Org__Repo_ { engine : String, org : String, repo : String }
    | Dash_Secrets_Engine__Repo_Org__Repo__Add { engine : String, org : String, repo : String }
    | Dash_Secrets_Engine__Repo_Org__Repo__Name_ { engine : String, org : String, repo : String, name : String }
    | Dash_Secrets_Engine__Shared_Org__Team_ { engine : String, org : String, team : String }
    | Dash_Secrets_Engine__Shared_Org__Team__Add { engine : String, org : String, team : String }
    | Dash_Secrets_Engine__Shared_Org__Team__Name_ { engine : String, org : String, team : String, name : String }
    | Org_ { org : String }
    | Org__Builds { org : String }
    | Org__Repo_ { org : String, repo : String }
    | Org__Repo__Deployments { org : String, repo : String }
    | Org__Repo__Deployments_Add { org : String, repo : String }
    | Org__Repo__Hooks { org : String, repo : String }
    | Org__Repo__Pulls { org : String, repo : String }
    | Org__Repo__Schedules { org : String, repo : String }
    | Org__Repo__Schedules_Add { org : String, repo : String }
    | Org__Repo__Schedules_Name_ { org : String, repo : String, name : String }
    | Org__Repo__Settings { org : String, repo : String }
    | Org__Repo__Tags { org : String, repo : String }
    | Org__Repo__Build_ { org : String, repo : String, build : String }
    | Org__Repo__Build__Graph { org : String, repo : String, build : String }
    | Org__Repo__Build__Pipeline { org : String, repo : String, build : String }
    | Org__Repo__Build__Services { org : String, repo : String, build : String }
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
            Just Home_

        "account" :: "authenticate" :: [] ->
            Just Account_Authenticate

        "account" :: "login" :: [] ->
            Just Account_Login

        "account" :: "logout" :: [] ->
            Just Account_Logout

        "account" :: "settings" :: [] ->
            Just Account_Settings

        "account" :: "source-repos" :: [] ->
            Just Account_SourceRepos

        "-" :: "secrets" :: engine_ :: "org" :: org_ :: [] ->
            Dash_Secrets_Engine__Org_Org_
                { engine = engine_
                , org = org_
                }
                |> Just

        "-" :: "secrets" :: engine_ :: "org" :: org_ :: "add" :: [] ->
            Dash_Secrets_Engine__Org_Org__Add
                { engine = engine_
                , org = org_
                }
                |> Just

        "-" :: "secrets" :: engine_ :: "org" :: org_ :: name_ :: [] ->
            Dash_Secrets_Engine__Org_Org__Name_
                { engine = engine_
                , org = org_
                , name = name_
                }
                |> Just

        "-" :: "secrets" :: engine_ :: "repo" :: org_ :: repo_ :: [] ->
            Dash_Secrets_Engine__Repo_Org__Repo_
                { engine = engine_
                , org = org_
                , repo = repo_
                }
                |> Just

        "-" :: "secrets" :: engine_ :: "repo" :: org_ :: repo_ :: "add" :: [] ->
            Dash_Secrets_Engine__Repo_Org__Repo__Add
                { engine = engine_
                , org = org_
                , repo = repo_
                }
                |> Just

        "-" :: "secrets" :: engine_ :: "repo" :: org_ :: repo_ :: name_ :: [] ->
            Dash_Secrets_Engine__Repo_Org__Repo__Name_
                { engine = engine_
                , org = org_
                , repo = repo_
                , name = name_
                }
                |> Just

        "-" :: "secrets" :: engine_ :: "shared" :: org_ :: team_ :: [] ->
            Dash_Secrets_Engine__Shared_Org__Team_
                { engine = engine_
                , org = org_
                , team = team_
                }
                |> Just

        "-" :: "secrets" :: engine_ :: "shared" :: org_ :: team_ :: "add" :: [] ->
            Dash_Secrets_Engine__Shared_Org__Team__Add
                { engine = engine_
                , org = org_
                , team = team_
                }
                |> Just

        "-" :: "secrets" :: engine_ :: "shared" :: org_ :: team_ :: name_ :: [] ->
            Dash_Secrets_Engine__Shared_Org__Team__Name_
                { engine = engine_
                , org = org_
                , team = team_
                , name = name_
                }
                |> Just

        org_ :: [] ->
            Org_
                { org = org_
                }
                |> Just

        org_ :: "builds" :: [] ->
            Org__Builds
                { org = org_
                }
                |> Just

        org_ :: repo_ :: [] ->
            Org__Repo_
                { org = org_
                , repo = repo_
                }
                |> Just

        org_ :: repo_ :: "deployments" :: [] ->
            Org__Repo__Deployments
                { org = org_
                , repo = repo_
                }
                |> Just

        org_ :: repo_ :: "deployments" :: "add" :: [] ->
            Org__Repo__Deployments_Add
                { org = org_
                , repo = repo_
                }
                |> Just

        org_ :: repo_ :: "hooks" :: [] ->
            Org__Repo__Hooks
                { org = org_
                , repo = repo_
                }
                |> Just

        org_ :: repo_ :: "pulls" :: [] ->
            Org__Repo__Pulls
                { org = org_
                , repo = repo_
                }
                |> Just

        org_ :: repo_ :: "schedules" :: [] ->
            Org__Repo__Schedules
                { org = org_
                , repo = repo_
                }
                |> Just

        org_ :: repo_ :: "schedules" :: "add" :: [] ->
            Org__Repo__Schedules_Add
                { org = org_
                , repo = repo_
                }
                |> Just

        org_ :: repo_ :: "schedules" :: name_ :: [] ->
            Org__Repo__Schedules_Name_
                { org = org_
                , repo = repo_
                , name = name_
                }
                |> Just

        org_ :: repo_ :: "settings" :: [] ->
            Org__Repo__Settings
                { org = org_
                , repo = repo_
                }
                |> Just

        org_ :: repo_ :: "tags" :: [] ->
            Org__Repo__Tags
                { org = org_
                , repo = repo_
                }
                |> Just

        org_ :: repo_ :: build_ :: [] ->
            Org__Repo__Build_
                { org = org_
                , repo = repo_
                , build = build_
                }
                |> Just

        org_ :: repo_ :: build_ :: "graph" :: [] ->
            Org__Repo__Build__Graph
                { org = org_
                , repo = repo_
                , build = build_
                }
                |> Just

        org_ :: repo_ :: build_ :: "pipeline" :: [] ->
            Org__Repo__Build__Pipeline
                { org = org_
                , repo = repo_
                , build = build_
                }
                |> Just

        org_ :: repo_ :: build_ :: "services" :: [] ->
            Org__Repo__Build__Services
                { org = org_
                , repo = repo_
                , build = build_
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
                Home_ ->
                    []

                Account_Authenticate ->
                    [ "account", "authenticate" ]

                Account_Login ->
                    [ "account", "login" ]

                Account_Logout ->
                    [ "account", "logout" ]

                Account_Settings ->
                    [ "account", "settings" ]

                Account_SourceRepos ->
                    [ "account", "source-repos" ]

                Dash_Secrets_Engine__Org_Org_ params ->
                    [ "-", "secrets", params.engine, "org", params.org ]

                Dash_Secrets_Engine__Org_Org__Add params ->
                    [ "-", "secrets", params.engine, "org", params.org, "add" ]

                Dash_Secrets_Engine__Org_Org__Name_ params ->
                    [ "-", "secrets", params.engine, "org", params.org, params.name ]

                Dash_Secrets_Engine__Repo_Org__Repo_ params ->
                    [ "-", "secrets", params.engine, "repo", params.org, params.repo ]

                Dash_Secrets_Engine__Repo_Org__Repo__Add params ->
                    [ "-", "secrets", params.engine, "repo", params.org, params.repo, "add" ]

                Dash_Secrets_Engine__Repo_Org__Repo__Name_ params ->
                    [ "-", "secrets", params.engine, "repo", params.org, params.repo, params.name ]

                Dash_Secrets_Engine__Shared_Org__Team_ params ->
                    [ "-", "secrets", params.engine, "shared", params.org, params.team ]

                Dash_Secrets_Engine__Shared_Org__Team__Add params ->
                    [ "-", "secrets", params.engine, "shared", params.org, params.team, "add" ]

                Dash_Secrets_Engine__Shared_Org__Team__Name_ params ->
                    [ "-", "secrets", params.engine, "shared", params.org, params.team, params.name ]

                Org_ params ->
                    [ params.org ]

                Org__Builds params ->
                    [ params.org, "builds" ]

                Org__Repo_ params ->
                    [ params.org, params.repo ]

                Org__Repo__Deployments params ->
                    [ params.org, params.repo, "deployments" ]

                Org__Repo__Deployments_Add params ->
                    [ params.org, params.repo, "deployments", "add" ]

                Org__Repo__Hooks params ->
                    [ params.org, params.repo, "hooks" ]

                Org__Repo__Pulls params ->
                    [ params.org, params.repo, "?event=pull_request" ]

                Org__Repo__Schedules params ->
                    [ params.org, params.repo, "schedules" ]

                Org__Repo__Schedules_Add params ->
                    [ params.org, params.repo, "schedules", "add" ]

                Org__Repo__Schedules_Name_ params ->
                    [ params.org, params.repo, "schedules", params.name ]

                Org__Repo__Settings params ->
                    [ params.org, params.repo, "settings" ]

                Org__Repo__Tags params ->
                    [ params.org, params.repo, "?event=tag" ]

                Org__Repo__Build_ params ->
                    [ params.org, params.repo, params.build ]

                Org__Repo__Build__Graph params ->
                    [ params.org, params.repo, params.build, "graph" ]

                Org__Repo__Build__Pipeline params ->
                    [ params.org, params.repo, params.build, "pipeline" ]

                Org__Repo__Build__Services params ->
                    [ params.org, params.repo, params.build, "services" ]

                NotFound_ ->
                    [ "not-found" ]
    in
    pieces
        |> String.join "/"
        |> String.append "/"
