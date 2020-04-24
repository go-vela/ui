{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.Secret exposing (view)

import Html
    exposing
        ( Html
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
        )
import Html.Events exposing (onClick)
import Pages exposing (Page(..))
import Pages.RepoSettings exposing (radio)
import Pages.Secrets.Form
    exposing
        ( viewEventsSelect
        , viewHelp
        , viewImagesInput
        , viewNameInput
        , viewValueInput
        )
import Pages.Secrets.Types exposing (Args, Msg(..), PartialModel, SecretForm)
import RemoteData exposing (RemoteData(..))
import Util
import Vela exposing (SecretType)


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
            text "View/Edit Org Secret"

        Vela.RepoSecret ->
            text "View/Edit Repo Secret"

        Vela.SharedSecret ->
            text "View/Edit Shared Secret"


{-| updateSecret : renders secret update form for updating a preexisting secret
-}
updateSecret : Args msg -> Html Msg
updateSecret secretsModel =
    let
        secretUpdate =
            secretsModel.form
    in
    div [ class "secret-form" ]
        [ Html.h4 [ class "field-header" ] [ text "Name" ]
        , viewNameInput secretUpdate.name True
        , Html.h4 [ class "field-header" ] [ text "Value" ]
        , viewValueInput secretUpdate.value "Secret Value (leave blank to make no change)"
        , viewEventsSelect secretUpdate
        , viewImagesInput secretUpdate secretUpdate.imageInput
        , viewHelp
        , div [ class "-m-t" ]
            [ Html.button [ class "button", class "-outline", onClick <| Pages.Secrets.Types.UpdateSecret secretsModel.engine ] [ text "Update" ]
            ]
        ]


{-| allowCommandCheckbox : renders checkbox inputs for selecting allowcommand
-}
allowCommandCheckbox : SecretForm -> Html Msg
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
