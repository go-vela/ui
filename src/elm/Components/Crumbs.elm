{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Crumbs exposing (Crumb, view)

import Html exposing (Html, a, li, ol, text)
import Html.Attributes exposing (attribute)
import Route.Path
import Tuple exposing (first, second)
import Url exposing (percentDecode)
import Utils.Helpers as Util



-- TYPES


type alias Crumb =
    ( String, Maybe Route.Path.Path )



-- VIEW


{-| view : takes current path and returns Html breadcrumbs
-}
view : Route.Path.Path -> List Crumb -> Html msg
view path crumbs =
    let
        items =
            List.map (\p -> item p path) crumbs
    in
    ol [ attribute "aria-label" "Breadcrumb" ] items


{-| item : uses page and current page, and returns Html breadcrumb item with possible href link
-}
item : Crumb -> Route.Path.Path -> Html msg
item crumb path =
    let
        link =
            first crumb

        decodedLink =
            link
                |> percentDecode
                |> Maybe.withDefault link

        testAttribute =
            Util.testAttribute <| Util.formatTestTag <| "crumb-" ++ decodedLink
    in
    case second crumb of
        Nothing ->
            li [ testAttribute ] [ text decodedLink ]

        Just p ->
            if p == path then
                li [ testAttribute, attribute "aria-current" "page" ] [ text decodedLink ]

            else
                li [ testAttribute ] [ a [ Route.Path.href p ] [ text decodedLink ] ]
