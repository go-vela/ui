{--
SPDX-License-Identifier: Apache-2.0
--}


module Route.Path exposing (Path(..), fromString, fromUrl, href, toString)

import Html
import Html.Attributes
import Url exposing (Url)
import Url.Parser exposing ((</>))



-- todo: vader: add all the normal routes


type Path
    = Home_
    | Login_
    | Logout_
    | Authenticate_
    | AccountSettings_
    | AccountSourceRepos_
    | Org_Repos { org : String }
    | Org_Repo_ { org : String, repo : String }
    | Org_Repo_Deployments_ { org : String, repo : String }
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

        [ "account", "login" ] ->
            Just Login_

        [ "account", "logout" ] ->
            Just Logout_

        [ "account", "authenticate" ] ->
            Just Authenticate_

        [ "account", "settings" ] ->
            Just AccountSettings_

        [ "account", "source-repos" ] ->
            Just AccountSourceRepos_

        org :: [] ->
            Org_Repos
                { org = org
                }
                |> Just

        org :: repo :: "deployments" :: [] ->
            Org_Repo_Deployments_
                { org = org
                , repo = repo
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
                Home_ ->
                    []

                Login_ ->
                    [ "account", "login" ]

                Logout_ ->
                    [ "account", "logout" ]

                Authenticate_ ->
                    [ "account", "authenticate" ]

                AccountSettings_ ->
                    [ "account", "settings" ]

                AccountSourceRepos_ ->
                    [ "account", "source-repos" ]

                Org_Repos params ->
                    [ params.org ]

                Org_Repo_ params ->
                    [ params.org, params.repo ]

                Org_Repo_Deployments_ params ->
                    [ params.org, params.repo, "deployments" ]

                NotFound_ ->
                    [ "404" ]
    in
    pieces
        |> String.join "/"
        |> String.append "/"
