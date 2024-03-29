{--
SPDX-License-Identifier: Apache-2.0
--}


module Route exposing (Route, fromUrl, href, parsePath, strip, toString)

import Dict exposing (Dict)
import Html
import Html.Attributes
import Route.Path
import Route.Query
import Url exposing (Url)


type alias Route params =
    { path : Route.Path.Path
    , params : params
    , query : Dict String String
    , hash : Maybe String
    , url : Url
    }


fromUrl : params -> Url -> Route params
fromUrl params url =
    { path = Route.Path.fromUrl url
    , params = params
    , query = Route.Query.fromUrl url
    , hash = url.fragment
    , url = url
    }


href : { path : Route.Path.Path, query : Dict String String, hash : Maybe String } -> Html.Attribute msg
href route =
    Html.Attributes.href (toString route)


toString : { route | path : Route.Path.Path, query : Dict String String, hash : Maybe String } -> String
toString route =
    String.join
        ""
        [ Route.Path.toString route.path
        , Route.Query.toString route.query
        , route.hash
            |> Maybe.map (String.append "#")
            |> Maybe.withDefault ""
        ]


strip : Route params -> { path : Route.Path.Path, query : Dict String String, hash : Maybe String }
strip route =
    { path = route.path
    , query = route.query
    , hash = route.hash
    }


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
