{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.NewPage.Update exposing (update)

import Pages.NewPage.Model
    exposing
        ( Msg(..)
        , PartialModel
        )
import RemoteData exposing (RemoteData(..))



-- UPDATE


update : PartialModel a -> Msg -> ( PartialModel a, Cmd msg )
update model msg =
    case msg of
        NoOp ->
            ( model, Cmd.none )
