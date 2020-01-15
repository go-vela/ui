{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Favorites exposing (FavoriteRepo, FavoritesModel, isFavorited)

import RemoteData exposing (WebData)
import Vela exposing (CurrentUser, Org, Repo, Session)


{-| PartialModel : an abbreviated version of the main model
-}
type alias FavoritesModel a =
    { a
        | velaAPI : String
        , session : Maybe Session
    }


{-| FavoriteRepo : takes org and maybe repo and toggles its favorite status them on Vela
-}
type alias FavoriteRepo msg =
    Org -> Maybe Repo -> msg


isFavorited : WebData CurrentUser -> String -> Bool
isFavorited user favorite =
    case user of
        RemoteData.Success u ->
            List.member favorite u.favorites

        _ ->
            False
