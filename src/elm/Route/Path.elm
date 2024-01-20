{--
SPDX-License-Identifier: Apache-2.0
--}


module Route.Path exposing (Path(..), fromString, fromUrl, href, toString)

import Html
import Html.Attributes
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
    | Org_Secrets { org : String }
    | Org_SecretsAdd { org : String }
    | Org_Repo_ { org : String, repo : String }
    | Org_Repo_Deployments { org : String, repo : String }
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

        org :: repo :: "deployments" :: [] ->
            Org_Repo_Deployments
                { org = org
                , repo = repo
                }
                |> Just

        org :: "builds" :: [] ->
            Org_Builds
                { org = org
                }
                |> Just

        org :: "secrets" :: [] ->
            Org_Secrets
                { org = org
                }
                |> Just

        org :: "secrets" :: "add" :: [] ->
            Org_SecretsAdd
                { org = org
                }
                |> Just

        org :: repo :: [] ->
            Org_Repo_
                { org = org
                , repo = repo
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

                Org_Secrets params ->
                    [ params.org, "secrets" ]

                Org_SecretsAdd params ->
                    [ params.org, "secrets", "add" ]

                Org_Repo_ params ->
                    [ params.org, params.repo ]

                Org_Repo_Deployments params ->
                    [ params.org, params.repo, "deployments" ]

                NotFound_ ->
                    [ "not-found" ]
    in
    pieces
        |> String.join "/"
        |> String.append "/"
