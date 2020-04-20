{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.Secret exposing (view)

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
import Pages.Secrets.Types exposing (Args, Msg(..), PartialModel, SecretUpdate)
import RemoteData exposing (RemoteData(..), WebData)
import Util exposing (stringToMaybe)
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
    div [] [ text "secret" ]


{-| toUpdateSecretPayload : builds payload for updating secret
-}
toUpdateSecretPayload : Args msg -> SecretUpdate -> UpdateSecretPayload
toUpdateSecretPayload secretsModel secret =
    let
        args =
            { type_ = Just secretsModel.type_
            , org = Nothing
            , repo = Nothing
            , team = Nothing
            , name = Nothing
            , value = stringToMaybe secret.value
            , events = Just secret.events
            , images = Just secret.images
            , allowCommand = Just secret.allowCommand
            }
    in
    buildUpdateSecretPayload args.type_ args.org args.repo args.team args.name args.value args.events args.images args.allowCommand


{-| allowCommandCheckbox : renders checkbox inputs for selecting allow\_command
-}
allowCommandCheckbox : SecretUpdate -> Html Msg
allowCommandCheckbox secretUpdate =
    section [ class "type", Util.testAttribute "" ]
        [ h4 [ class "field-header" ]
            [ text "Allow Commands"
            , span [ class "field-description" ]
                [ text "( "
                , em [] [ text "\"No\" will disable this secret in " ]
                , span [ class "-code" ] [ text "commands" ]
                , text " )"
                ]
            ]
        , div
            [ class "form-controls", class "-row" ]
            [ radio (Util.boolToYesNo secretUpdate.allowCommand) "yes" "Yes" <| OnChangeAllowCommand "yes"
            , radio (Util.boolToYesNo secretUpdate.allowCommand) "no" "No" <| OnChangeAllowCommand "no"
            ]
        ]
