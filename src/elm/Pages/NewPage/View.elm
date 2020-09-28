{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Analyze.View exposing (viewAnalysis)

import Html
    exposing
        ( Html
        , div
        , text
        )
import Http exposing (Error(..))
import Pages exposing (Page(..))
import Pages.Analyze.Model exposing (Msg(..), PartialModel)
import Routes exposing (Route(..))
import Vela
    exposing
        ( Org
        , Repo
        )



-- VIEW


viewAnalysis : PartialModel a -> Org -> Repo -> Html Msg
viewAnalysis model org repo =
    div [] [ text "model.build.org" ]
