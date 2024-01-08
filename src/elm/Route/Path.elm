module Route.Path exposing (Path(..), fromString, fromUrl, href, toString)

import Html
import Html.Attributes
import Url exposing (Url)
import Url.Parser exposing ((</>))



-- todo: vader: add all the normal routes


type Path
    = Home_
    | Deployments_ String String
    | Login_
    | Authenticate_
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

        [ "account", "authenticate" ] ->
            Just Authenticate_

        -- todo: how do you add a dynamic route? <org>/<repo>/deployments
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

                Authenticate_ ->
                    [ "account", "authenticate" ]

                Deployments_ org repo ->
                    [ org, repo, "deployments" ]

                NotFound_ ->
                    [ "404" ]
    in
    pieces
        |> String.join "/"
        |> String.append "/"
