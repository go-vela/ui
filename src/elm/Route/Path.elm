{--
SPDX-License-Identifier: Apache-2.0
--}


module Route.Path exposing (Path(..), fromString, fromUrl, href, parsePath, toString)

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
    | SecretsEngine_OrgOrg_ { org : String, engine : String }
    | SecretsEngine_OrgOrg_Add { org : String, engine : String }
    | SecretsEngine_OrgOrg_Edit_ { org : String, name : String, engine : String }
    | Org_Repo_ { org : String, repo : String }
    | Org_Repo_Deployments { org : String, repo : String }
    | Org_Repo_DeploymentsAdd { org : String, repo : String }
    | Org_Repo_Schedules { org : String, repo : String }
    | Org_Repo_SchedulesAdd { org : String, repo : String }
    | Org_Repo_SchedulesEdit_ { org : String, repo : String, name : String }
    | Org_Repo_Audit { org : String, repo : String }
    | Org_Repo_Settings { org : String, repo : String }
    | SecretsEngine_RepoOrg_Repo_ { org : String, repo : String, engine : String }
    | SecretsEngine_RepoOrg_Repo_Add { org : String, repo : String, engine : String }
    | SecretsEngine_RepoOrg_Repo_Edit_ { org : String, repo : String, name : String, engine : String }
    | Org_Repo_Build_ { org : String, repo : String, buildNumber : String }
    | Org_Repo_Build_Services { org : String, repo : String, buildNumber : String }
    | Org_Repo_Build_Pipeline { org : String, repo : String, buildNumber : String }
    | Org_Repo_Build_Graph { org : String, repo : String, buildNumber : String }
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

        "-" :: "secrets" :: engine :: "org" :: org :: [] ->
            SecretsEngine_OrgOrg_
                { org = org
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "org" :: org :: "add" :: [] ->
            SecretsEngine_OrgOrg_Add
                { org = org
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "org" :: org :: name :: [] ->
            SecretsEngine_OrgOrg_Edit_
                { org = org
                , name = name
                , engine = engine
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
            Org_Repo_SchedulesEdit_
                { org = org
                , repo = repo
                , name = name
                }
                |> Just

        org :: repo :: "audit" :: [] ->
            Org_Repo_Audit
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

        "-" :: "secrets" :: engine :: "repo" :: org :: repo :: [] ->
            SecretsEngine_RepoOrg_Repo_
                { org = org
                , repo = repo
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "repo" :: org :: repo :: "add" :: [] ->
            SecretsEngine_RepoOrg_Repo_Add
                { org = org
                , repo = repo
                , engine = engine
                }
                |> Just

        "-" :: "secrets" :: engine :: "repo" :: org :: repo :: name :: [] ->
            SecretsEngine_RepoOrg_Repo_Edit_
                { org = org
                , repo = repo
                , name = name
                , engine = engine
                }
                |> Just

        org :: repo :: buildNumber :: [] ->
            Org_Repo_Build_
                { org = org
                , repo = repo
                , buildNumber = buildNumber
                }
                |> Just

        org :: repo :: buildNumber :: "services" :: [] ->
            Org_Repo_Build_Services
                { org = org
                , repo = repo
                , buildNumber = buildNumber
                }
                |> Just

        org :: repo :: buildNumber :: "pipeline" :: [] ->
            Org_Repo_Build_Pipeline
                { org = org
                , repo = repo
                , buildNumber = buildNumber
                }
                |> Just

        org :: repo :: buildNumber :: "graph" :: [] ->
            Org_Repo_Build_Graph
                { org = org
                , repo = repo
                , buildNumber = buildNumber
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

                SecretsEngine_OrgOrg_ params ->
                    [ "-", "secrets", params.engine, "org", params.org ]

                SecretsEngine_OrgOrg_Add params ->
                    [ "-", "secrets", params.engine, "org", params.org, "add" ]

                SecretsEngine_OrgOrg_Edit_ params ->
                    [ "-", "secrets", params.engine, "org", params.org, params.name ]

                Org_Repo_ params ->
                    [ params.org, params.repo ]

                Org_Repo_Deployments params ->
                    [ params.org, params.repo, "deployments" ]

                Org_Repo_DeploymentsAdd params ->
                    [ params.org, params.repo, "deployments", "add" ]

                Org_Repo_Schedules params ->
                    [ params.org, params.repo, "schedules" ]

                Org_Repo_SchedulesAdd params ->
                    [ params.org, params.repo, "schedules", "add" ]

                Org_Repo_SchedulesEdit_ params ->
                    [ params.org, params.repo, "schedules", params.name ]

                Org_Repo_Audit params ->
                    [ params.org, params.repo, "audit" ]

                Org_Repo_Settings params ->
                    [ params.org, params.repo, "settings" ]

                SecretsEngine_RepoOrg_Repo_ params ->
                    [ "-", "secrets", params.engine, "repo", params.org, params.repo ]

                SecretsEngine_RepoOrg_Repo_Add params ->
                    [ "-", "secrets", params.engine, "repo", params.org, params.repo, "add" ]

                SecretsEngine_RepoOrg_Repo_Edit_ params ->
                    [ "-", "secrets", params.engine, "repo", params.org, params.repo, params.name ]

                Org_Repo_Build_ params ->
                    [ params.org, params.repo, params.buildNumber ]

                Org_Repo_Build_Services params ->
                    [ params.org, params.repo, params.buildNumber, "services" ]

                Org_Repo_Build_Pipeline params ->
                    [ params.org, params.repo, params.buildNumber, "pipeline" ]

                Org_Repo_Build_Graph params ->
                    [ params.org, params.repo, params.buildNumber, "graph" ]

                NotFound_ ->
                    [ "not-found" ]
    in
    pieces
        |> String.join "/"
        |> String.append "/"


parsePath :
    String
    ->
        { path : String
        , query : Maybe String
        , hash : Maybe String
        }
parsePath urlString =
    let
        pathsAndHash =
            String.split "#" urlString

        maybeHash =
            List.head <| List.drop 1 pathsAndHash

        pathsAndQuery =
            String.split "?" <| Maybe.withDefault "" <| List.head pathsAndHash

        pathSegments =
            String.split "/" <| Maybe.withDefault "" <| List.head pathsAndQuery

        maybeQuery =
            List.head <| List.drop 1 pathsAndQuery
    in
    { path = String.join "/" pathSegments, query = maybeQuery, hash = maybeHash }
