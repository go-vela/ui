{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Favorites exposing (FavoritesModel)

import Vela exposing (Session)


{-| PartialModel : an abbreviated version of the main model
-}
type alias FavoritesModel a =
    { a
        | velaAPI : String
        , session : Maybe Session
    }
