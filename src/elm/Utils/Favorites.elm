{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Favorites exposing (UpdateFavorites, UpdateType(..), addFavorite, addFavorites, isFavorited, toFavorite, toggleFavorite)

import List.Extra
import RemoteData exposing (WebData)
import Vela



-- TYPES


{-| UpdateFavorites : alias for a function that takes an organization and a maybe repo and returns a message.
-}
type alias UpdateFavorites msg =
    Vela.Org -> Maybe Vela.Repo -> msg


{-| UpdateType : possible update types.
-}
type UpdateType
    = Add
    | Toggle


{-| isFavorited : takes current user and favorite key and returns if the repo is favorited by that user.
-}
isFavorited : String -> String -> WebData Vela.User -> Bool
isFavorited org repo user =
    case user of
        RemoteData.Success u ->
            List.member (org ++ "/" ++ repo) u.favorites

        _ ->
            False


{-| toggleFavorite : takes current user and favorite key and updates/returns that user's list of favorites.
-}
toggleFavorite : WebData Vela.User -> String -> ( List String, Bool )
toggleFavorite user favorite =
    case user of
        RemoteData.Success u ->
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


{-| addFavorite : takes current user and favorite key and adds favorite to list of favorites.
-}
addFavorite : WebData Vela.User -> String -> ( List String, Bool )
addFavorite user favorite =
    case user of
        RemoteData.Success u ->
            let
                favorites =
                    List.Extra.unique <| favorite :: u.favorites
            in
            ( favorites, True )

        _ ->
            ( [], False )


{-| addFavorites : takes current user and adds favorites to the current list of favorites.
-}
addFavorites : WebData Vela.User -> List { org : String, maybeRepo : Maybe String } -> List String
addFavorites user favorites =
    case user of
        RemoteData.Success u ->
            favorites
                |> List.map (\f -> toFavorite f.org f.maybeRepo)
                |> (\favs -> List.Extra.unique <| favs ++ u.favorites)

        _ ->
            []


{-| toFavorite : takes org and maybe repo and builds the appropriate favorites key.
-}
toFavorite : Vela.Org -> Maybe Vela.Repo -> String
toFavorite org repo =
    org ++ "/" ++ Maybe.withDefault "*" repo
