{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Update exposing (update)

import Pages.Pipeline.Model
    exposing
        ( Msg(..)
        , PartialModel
        ,ExpandPipelineConfigResponse
        )
import RemoteData exposing (RemoteData(..))
import Api
import Http.Detailed
import Vela exposing (Org, Repo)
-- UPDATE


update : PartialModel a -> Msg -> ExpandPipelineConfigResponse msg -> ( PartialModel a, Cmd msg )
update model msg expandPipelineConfigResponse =
    case msg of
        ExpandPipelineConfig org repo ref ->
            ( model, expandPipelineConfig model org repo ref expandPipelineConfigResponse )

expandPipelineConfig : PartialModel a -> Org -> Repo -> Maybe String -> ExpandPipelineConfigResponse msg ->  Cmd msg
expandPipelineConfig model org repo ref expandPipelineConfigResponse =
    Api.tryString (expandPipelineConfigResponse org repo) <| Api.expandPipelineConfig model org repo ref
