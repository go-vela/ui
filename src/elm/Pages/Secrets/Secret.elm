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
import Pages exposing (Page(..))
import Pages.RepoSettings exposing (checkbox, radio)
import Pages.Secrets.Form
    exposing
        ( viewAddedImages
        , viewEventsSelect
        , viewHelp
        , viewImagesInput
        , viewNameInput
        , viewValueInput
        )
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


view : PartialModel a msg -> Html Msg
view model =
    div [ class "manage-secrets", Util.testAttribute "manage-secrets" ]
        [ div []
            [ Html.h2 [] [ header model.secretsModel.type_ ]
            , updateSecret model.secretsModel
            ]
        ]


header : SecretType -> Html Msg
header type_ =
    case type_ of
        Vela.OrgSecret ->
            text "Org Secret"

        Vela.RepoSecret ->
            text "Repo Secret"

        Vela.SharedSecret ->
            text "Shared Secret"


{-| updateSecret : renders secret update form for updating a preexisting secret
-}
updateSecret : Args msg -> Html Msg
updateSecret secretsModel =
    let
        secretUpdate =
            secretsModel.secretAdd
    in
    div [ class "secret-form" ]
        [ Html.h4 [ class "field-header" ] [ text "Name" ]
        , Html.h4 [ class "field-header" ] [ text "Value" ]
        , viewValueInput secretUpdate.value "Secret Value"
        , viewEventsSelect secretUpdate
        , viewImagesInput secretUpdate secretUpdate.imageInput
        , viewHelp
        , div [ class "-m-t" ]
            [ Html.button [ class "button", class "-outline", onClick Pages.Secrets.Types.AddSecret ] [ text "Add" ]
            ]
        ]


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
