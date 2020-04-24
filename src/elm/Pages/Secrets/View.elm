{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.View exposing (addSecret, editSecret, secrets)

import Html
    exposing
        ( Html
        , a
        , div
        , em
        , h4
        , text
        )
import Html.Attributes
    exposing
        ( class
        , href
        )
import Html.Events exposing (onClick)
import Pages.Secrets.Form
    exposing
        ( viewEventsSelect
        , viewHelp
        , viewImagesInput
        , viewNameInput
        , viewValueInput
        )
import Pages.Secrets.Model
    exposing
        ( ManageSecretState(..)
        , Model
        , Msg(..)
        , PartialModel
        , SecretForm
        )
import RemoteData exposing (RemoteData(..))
import Routes
import Table.Table
import Util exposing (largeLoader)
import Vela
    exposing
        ( Secret
        , SecretType(..)
        , Secrets
        , secretTypeToString
        )



-- SECRETS


{-| secrets : takes model and renders page for managing secrets
-}
secrets : PartialModel a msg -> Html Msg
secrets model =
    let
        secretsModel =
            model.secretsModel

        ( label, noSecrets, addSecretRoute ) =
            case model.secretsModel.type_ of
                Vela.OrgSecret ->
                    ( "Org Secrets"
                    , "No secrets found for this organization"
                    , Routes.AddOrgSecret "native" secretsModel.org
                    )

                Vela.RepoSecret ->
                    ( "Repo Secrets"
                    , "No secrets found for this repository"
                    , Routes.AddRepoSecret "native" secretsModel.org secretsModel.repo
                    )

                Vela.SharedSecret ->
                    ( "Shared Secrets"
                    , "No secrets found for this organization/team"
                    , Routes.AddSharedSecret "native" secretsModel.org secretsModel.team
                    )

        add =
            Just <|
                a
                    [ class "add-secret"
                    , class "button"
                    , class "-outline"
                    , Routes.href <|
                        addSecretRoute
                    ]
                    [ text "Add Secret" ]
    in
    case secretsModel.secrets of
        Success s ->
            div []
                [ Table.Table.view
                    (Table.Table.Config label
                        noSecrets
                        tableHeaders
                        (secretsToRows model.secretsModel.type_ s)
                        add
                    )
                ]

        _ ->
            div [] [ largeLoader ]


secretsToRows : SecretType -> Secrets -> Table.Table.Rows Secret Msg
secretsToRows type_ =
    List.map (\secret -> Table.Table.Row secret (renderSecret type_))


tableHeaders : List String
tableHeaders =
    [ "name", "type", "events", "images", "allow command" ]


renderSecret : SecretType -> Secret -> Html msg
renderSecret type_ secret =
    div [ class "row", class "preview" ]
        [ Table.Table.customCell (Html.a [ updateSecretHref type_ secret ] [ text secret.name ]) <| class ""
        , Table.Table.cell (secretTypeToString secret.type_) <| class ""
        , Table.Table.arrayCell secret.events "no events"
        , Table.Table.arrayCell secret.images "all images"
        , Table.Table.cell (Util.boolToYesNo secret.allowCommand) <| class ""

        -- TODO: change linked name to edit button, when table is fixed
        -- , Table.Table.customCell (Html.a [ class "button", class "-outline", updateSecretHref type_ secret ] [ text "edit" ]) <| class ""
        ]


updateSecretHref : SecretType -> Secret -> Html.Attribute msg
updateSecretHref type_ secret =
    Routes.href <|
        case type_ of
            Vela.OrgSecret ->
                Routes.OrgSecret "native" secret.org secret.name

            Vela.RepoSecret ->
                Routes.RepoSecret "native" secret.org secret.repo secret.name

            Vela.SharedSecret ->
                Routes.SharedSecret "native" secret.org secret.team secret.name



-- ADD SECRET


addSecret : PartialModel a msg -> Html Msg
addSecret model =
    div [ class "manage-secret", Util.testAttribute "manage-secret" ]
        [ div []
            [ Html.h2 [] [ addHeader model.secretsModel.type_ ]
            , addForm model.secretsModel
            ]
        ]


addHeader : SecretType -> Html Msg
addHeader type_ =
    case type_ of
        Vela.OrgSecret ->
            text "Add Org Secret"

        Vela.RepoSecret ->
            text "Add Repo Secret"

        Vela.SharedSecret ->
            text "Add Shared Secret"


{-| addForm : renders secret update form for adding a new secret
-}
addForm : Model msg -> Html Msg
addForm secretsModel =
    let
        secretUpdate =
            secretsModel.form
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
            [ Html.button [ class "button", class "-outline", onClick <| Pages.Secrets.Model.AddSecret secretsModel.engine ] [ text "Add" ]
            ]
        ]



-- EDIT SECRET


editSecret : PartialModel a msg -> Html Msg
editSecret model =
    div [ class "manage-secret", Util.testAttribute "manage-secret" ]
        [ div []
            [ Html.h2 [] [ editHeader model.secretsModel.type_ ]
            , editForm model.secretsModel
            ]
        ]


editHeader : SecretType -> Html Msg
editHeader type_ =
    case type_ of
        Vela.OrgSecret ->
            text "View/Edit Org Secret"

        Vela.RepoSecret ->
            text "View/Edit Repo Secret"

        Vela.SharedSecret ->
            text "View/Edit Shared Secret"


{-| editForm : renders secret update form for updating a preexisting secret
-}
editForm : Model msg -> Html Msg
editForm secretsModel =
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

        -- , allowCommandCheckbox secretUpdate
        , viewHelp
        , div [ class "-m-t" ]
            [ Html.button [ class "button", class "-outline", onClick <| Pages.Secrets.Model.UpdateSecret secretsModel.engine ] [ text "Update" ]
            ]
        ]
