{--
SPDX-License-Identifier: Apache-2.0
--}


module Favorites exposing (ToggleFavorite, addFavorite, isFavorited, starToggle, toFavorite, updateFavorites)

import Html exposing (Html, button)
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import List.Extra
import RemoteData exposing (RemoteData(..), WebData)
import SvgBuilder exposing (star)
import Util
import Vela exposing (CurrentUser, Org, Repo)


{-| ToggleFavorite : takes org and maybe repo and toggles its favorite status them on Vela
-}
type alias ToggleFavorite msg =
    Org -> Maybe Repo -> msg



-- VIEW


{-| starToggle : takes org repo msg and favorited status and renders the favorites toggle star
-}
starToggle : Org -> Repo -> ToggleFavorite msg -> Bool -> Html msg
starToggle org repo toggleFavorite favorited =
    button
        [ Util.testAttribute <| "star-toggle-" ++ org ++ "-" ++ repo
        , onClick <| toggleFavorite org <| Just repo
        , starToggleAriaLabel org repo favorited
        , class "button"
        , class "-icon"
        ]
        [ star favorited ]


starToggleAriaLabel : Org -> Repo -> Bool -> Html.Attribute msg
starToggleAriaLabel org repo favorited =
    let
        favorite =
            toFavorite org <| Just repo
    in
    attribute "aria-label" <|
        if favorited then
            "remove " ++ favorite ++ " from user favorites"

        else
            "add " ++ favorite ++ " to user favorites"



-- HELPERS


{-| isFavorited : takes current user and favorite key and returns if the repo is favorited by that user
-}
isFavorited : WebData CurrentUser -> String -> Bool
isFavorited user favorite =
    case user of
        RemoteData.Success u ->
            List.member favorite u.favorites

        _ ->
            False


{-| updateFavorites : takes current user and favorite key and updates/returns that user's list of favorites
-}
updateFavorites : WebData CurrentUser -> String -> ( List String, Bool )
updateFavorites user favorite =
    case user of
        Success u ->
            let
                favorited =
                    List.member favorite u.favorites

                favorites =
                    if favorited then
                        List.Extra.remove favorite u.favorites

                    else
                        List.Extra.unique <| favorite :: u.favorites
            in
            ( favorites, not favorited )

        _ ->
            ( [], False )


{-| addFavorite : takes current user and favorite key and adds favorite to list of favorites
-}
addFavorite : WebData CurrentUser -> String -> ( List String, Bool )
addFavorite user favorite =
    case user of
        Success u ->
            let
                favorites =
                    List.Extra.unique <| favorite :: u.favorites
            in
            ( favorites, True )

        _ ->
            ( [], False )


{-| toFavorite : takes org and maybe repo and builds the appropriate favorites key
-}
toFavorite : Org -> Maybe Repo -> String
toFavorite org repo =
    org ++ "/" ++ Maybe.withDefault "*" repo
