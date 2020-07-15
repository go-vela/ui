{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.View exposing (addSecret, editSecret, secrets)

import Errors exposing (viewResourceError)
import Html
    exposing
        ( Html
        , a
        , button
        , div
        , h2
        , span
        , td
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , href
        , scope
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
        , secretsResourceKey
        )
import RemoteData exposing (RemoteData(..))
import Routes
import Table
import Url exposing (percentEncode)
import Util exposing (largeLoader)
import Vela
    exposing
        ( Secret
        , SecretType(..)
        , Secrets
        , secretTypeToString
        , secretsErrorLabel
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
            case secretsModel.type_ of
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
                    [ addLabel secretsModel.type_ ]

        testLabel =
            "secrets"
    in
    case secretsModel.secrets of
        Success s ->
            div []
                [ Table.view
                    (Table.Config
                        label
                        testLabel
                        noSecrets
                        tableHeaders
                        (secretsToRows model.secretsModel.type_ s)
                        add
                    )
                ]

        RemoteData.Failure _ ->
            viewResourceError
                { resourceLabel =
                    secretsErrorLabel secretsModel.type_
                        secretsModel.org
                    <|
                        secretsResourceKey secretsModel
                , testLabel = testLabel
                }

        _ ->
            div [] [ largeLoader ]


{-| secretsToRows : takes list of secrets and produces list of Table rows
-}
secretsToRows : SecretType -> Secrets -> Table.Rows Secret Msg
secretsToRows type_ =
    List.map (\secret -> Table.Row secret (renderSecret type_))


{-| tableHeaders : returns table headers for secrets table
-}
tableHeaders : List String
tableHeaders =
    [ "name", "type", "events", "images", "allow command" ]


{-| renderSecret : takes secret and secret type and renders a table row
-}
renderSecret : SecretType -> Secret -> Html msg
renderSecret type_ secret =
    tr [ Util.testAttribute <| "secrets-row" ]
        [ td
            [ attribute "data-label" "name"
            , scope "row"
            , class "-line-break"
            , Util.testAttribute <| "secrets-row-name"
            ]
            [ a [ updateSecretHref type_ secret ] [ text secret.name ] ]
        , td
            [ attribute "data-label" "type"
            , scope "row"
            , class "-line-break"
            ]
            [ text <| secretTypeToString secret.type_ ]
        , td
            [ attribute "data-label" "events"
            , scope "row"
            , class "-line-break"
            ]
          <|
            renderListCell secret.events "no events" "secret-event"
        , td
            [ attribute "data-label" "images"
            , scope "row"
            , class "-line-break"
            ]
          <|
            renderListCell secret.images "no images" "secret-image"
        , td
            [ attribute "data-label" "allow command"
            , scope "row"
            , class "-line-break"
            ]
            [ text <| Util.boolToYesNo secret.allowCommand ]
        ]


{-| renderListCell : takes list of items, text for none and className and renders a table cell
-}
renderListCell : List String -> String -> String -> List (Html msg)
renderListCell items none itemClassName =
    if List.length items == 0 then
        [ text none ]

    else
        let
            content =
                items
                    |> List.sort
                    |> List.indexedMap
                        (\i item ->
                            if i + 1 < List.length items then
                                Just <| item ++ ", "

                            else
                                Just item
                        )
                    |> List.filterMap identity
                    |> String.concat
        in
        [ Html.code [ class itemClassName ] [ span [] [ text content ] ] ]


{-| updateSecretHref : takes secret and secret type and returns href link for routing to view/edit secret page
-}
updateSecretHref : SecretType -> Secret -> Html.Attribute msg
updateSecretHref type_ secret =
    let
        encodedTeam =
            percentEncode secret.team

        encodedName =
            percentEncode secret.name
    in
    Routes.href <|
        case type_ of
            Vela.OrgSecret ->
                Routes.OrgSecret "native" secret.org encodedName

            Vela.RepoSecret ->
                Routes.RepoSecret "native" secret.org secret.repo encodedName

            Vela.SharedSecret ->
                Routes.SharedSecret "native" secret.org encodedTeam encodedName



-- ADD SECRET


{-| addSecret : takes partial model and renders the Add Secret form
-}
addSecret : PartialModel a msg -> Html Msg
addSecret model =
    div [ class "manage-secret", Util.testAttribute "manage-secret" ]
        [ div []
            [ h2 [] [ addLabel model.secretsModel.type_ ]
            , addForm model.secretsModel
            ]
        ]


{-| addLabel : takes secret type and renders the Add Secret header label
-}
addLabel : SecretType -> Html Msg
addLabel type_ =
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
        [ viewNameInput secretUpdate.name False
        , viewValueInput secretUpdate.value "Secret Value"
        , viewEventsSelect secretUpdate
        , viewImagesInput secretUpdate secretUpdate.imageInput
        , viewHelp
        , div [ class "form-action" ]
            [ button [ class "button", class "-outline", onClick <| Pages.Secrets.Model.AddSecret secretsModel.engine ] [ text "Add" ]
            ]
        ]



-- EDIT SECRET


{-| editSecret : takes partial model and renders secret update form for editing a secret
-}
editSecret : PartialModel a msg -> Html Msg
editSecret model =
    case model.secretsModel.secret of
        Success _ ->
            div [ class "manage-secret", Util.testAttribute "manage-secret" ]
                [ div []
                    [ h2 [] [ editHeader model.secretsModel.type_ ]
                    , editForm model.secretsModel
                    ]
                ]

        Failure _ ->
            viewResourceError { resourceLabel = "secret", testLabel = "secret" }

        _ ->
            text ""


{-| editHeader : takes secret type and renders view/edit secret header
-}
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
    div [ class "secret-form", class "edit-form" ]
        [ viewNameInput secretUpdate.name True
        , viewValueInput secretUpdate.value "Secret Value (leave blank to make no change)"
        , viewEventsSelect secretUpdate
        , viewImagesInput secretUpdate secretUpdate.imageInput

        -- , allowCommandCheckbox secretUpdate
        , viewHelp
        , div [ class "form-action" ]
            [ button [ class "button", class "-outline", onClick <| Pages.Secrets.Model.UpdateSecret secretsModel.engine ] [ text "Update" ]
            ]
        ]
