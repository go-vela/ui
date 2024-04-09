{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Favorites exposing (starToggleAriaLabel, viewStarToggle)

import Components.Svgs exposing (star)
import Html exposing (Html, button, text)
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Utils.Favorites as Favorites
import Utils.Helpers as Util
import Vela



-- VIEW


{-| viewStarToggle : renders star toggle.
-}
viewStarToggle :
    { msg : Vela.Org -> Maybe Vela.Repo -> msg
    , user : WebData Vela.CurrentUser
    , org : Vela.Org
    , repo : Vela.Repo
    }
    -> Html msg
viewStarToggle { msg, user, org, repo } =
    button
        [ Util.testAttribute <| "star-toggle-" ++ org ++ "-" ++ repo
        , onClick <| msg org (Just repo)
        , starToggleAriaLabel org repo <| Favorites.isFavorited org repo user
        , class "button"
        , class "-icon"
        ]
        [ star <| Favorites.isFavorited org repo user ]


{-| starToggleAriaLabel : renders appropriate aria label for add or remove favorite.
-}
starToggleAriaLabel : Vela.Org -> Vela.Repo -> Bool -> Html.Attribute msg
starToggleAriaLabel org repo favorited =
    let
        favorite =
            Favorites.toFavorite org <| Just repo
    in
    attribute "aria-label" <|
        if favorited then
            "remove " ++ favorite ++ " from user favorites"

        else
            "add " ++ favorite ++ " to user favorites"
