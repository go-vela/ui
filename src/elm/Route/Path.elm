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
    | Deployments_
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

        -- todo: how do you add a dynamic route? <org>/<repo>/deployments
        [ "deployments" ] ->
            Just Deployments_

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

                Deployments_ ->
                    [ "deployments" ]

                NotFound_ ->
                    [ "404" ]
    in
    pieces
        |> String.join "/"
        |> String.append "/"
