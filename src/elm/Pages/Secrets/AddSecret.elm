{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.AddSecret exposing (header, view)

import Html
    exposing
        ( Html
        , a
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
import Pages.RepoSettings exposing (checkbox)
import Pages.Secrets.Form exposing (viewAddedImages, viewEventsSelect, viewHelp, viewImagesInput, viewNameInput, viewValueInput)
import Pages.Secrets.Types
    exposing
        ( Args
        , Msg(..)
        , PartialModel
        , SecretUpdate
        )
import RemoteData exposing (RemoteData(..))
import Util
import Vela
    exposing
        ( SecretType(..)
        )


view : PartialModel a msg -> Html Msg
view model =
    div [ class "manage-secrets", Util.testAttribute "manage-secrets" ]
        [ div []
            [ Html.h2 [] [ header model.secretsModel.type_ ]
            , addSecret model.secretsModel
            ]
        ]


header : SecretType -> Html Msg
header type_ =
    case type_ of
        Vela.OrgSecret ->
            text "Add Org Secret"

        Vela.RepoSecret ->
            text "Add Repo Secret"

        Vela.SharedSecret ->
            text "Add Shared Secret"


{-| addSecret : renders secret update form for adding a new secret
-}
addSecret : Args msg -> Html Msg
addSecret secretsModel =
    let
        secretUpdate =
            secretsModel.secretAdd
    in
    div [ class "secret-form" ]
        [ Html.h4 [ class "field-header" ] [ text "Name" ]
        , viewNameInput secretUpdate.name False
        , Html.h4 [ class "field-header" ] [ text "Value" ]
        , viewValueInput secretUpdate.value "Secret Value"
        , viewEventsSelect secretUpdate
        , viewImagesInput secretUpdate secretUpdate.imageInput
        , viewHelp
        , div [ class "-m-t" ]
            [ Html.button [ class "button", class "-outline", onClick Pages.Secrets.Types.AddSecret ] [ text "Add" ]
            ]
        ]
