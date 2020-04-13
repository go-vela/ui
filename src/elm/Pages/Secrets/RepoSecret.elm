{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.RepoSecret exposing (view)

import Api
import Html
    exposing
        ( Html
        , a
        , code
        , div
        , em
        , h4
        , section
        , span
        , text
        )
import Html.Attributes
    exposing
        ( class
        , disabled
        , href
        , placeholder
        , value
        )
import Html.Events exposing (onClick, onInput)
import Http
import Http.Detailed
import List.Extra
import Pages exposing (Page(..))
import Pages.RepoSettings exposing (checkbox, radio)
import Pages.Secrets.Types exposing (Msg(..), PartialModel)
import RemoteData exposing (RemoteData(..), WebData)
import Util exposing (largeLoader)
import Vela
    exposing
        ( Key
        , Org
        , Repo
        , Secret
        , SecretType
        , Secrets
        , Session
        , Team
        , UpdateSecretPayload
        , buildUpdateSecretPayload
        , encodeUpdateSecret
        , nullSecret
        , secretTypeToString
        , toSecretType
        )


{-| view : takes model and renders page for managing org secrets
-}
view : PartialModel a msg -> Html Msg
view model =
    div [] [ text "repo secret" ]
