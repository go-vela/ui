{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Api exposing (expandPipelineConfig, getPipelineConfig, getPipelineTemplates)

import Api
import Pages.Pipeline.Model exposing (Msg(..), PartialModel)
import Vela exposing (FocusFragment, Org, Ref, Repo)


{-| getPipelineConfig : takes model, org, repo and ref and fetches a pipeline configuration from the API.
-}
getPipelineConfig : PartialModel a -> Org -> Repo -> Maybe Ref -> Cmd Msg
getPipelineConfig model org repo ref =
    Api.tryString (GetPipelineConfigResponse org repo ref) <| Api.getPipelineConfig model org repo ref


{-| expandPipelineConfig : takes model, org, repo and ref and expands a pipeline configuration via the API.
-}
expandPipelineConfig : PartialModel a -> Org -> Repo -> Maybe Ref -> Cmd Msg
expandPipelineConfig model org repo ref =
    Api.tryString (ExpandPipelineConfigResponse org repo ref) <| Api.expandPipelineConfig model org repo ref


{-| getPipelineTemplates : takes model, org, repo and ref and fetches templates used in a pipeline configuration from the API.
-}
getPipelineTemplates : PartialModel a -> Org -> Repo -> Maybe Ref -> FocusFragment -> Cmd Msg
getPipelineTemplates model org repo ref lineFocus =
    Api.try (GetPipelineTemplatesResponse org repo lineFocus) <| Api.getPipelineTemplates model org repo ref
