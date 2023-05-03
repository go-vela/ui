{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Schedules.View exposing (addSchedule, viewRepoSchedules)

import Errors exposing (viewResourceError)
import FeatherIcons
import Html exposing (Html, a, button, div, h2, span, td, text, tr)
import Html.Attributes exposing (attribute, class, scope)
import Html.Events exposing (onClick)
import Http
import Pages.Schedules.Form exposing (viewEnabledCheckbox, viewHelp, viewNameInput, viewSubmitButtons, viewValueInput)
import Pages.Schedules.Model exposing (Model, Msg, PartialModel)
import RemoteData exposing (RemoteData(..))
import Routes
import Svg.Attributes
import Table
import Util exposing (largeLoader)
import Vela exposing (Schedule, Schedules, Schedule, SecretType(..))



-- VIEW


{-| viewRepoSecrets : takes secrets model and renders table for viewing repo secrets
-}
viewRepoSchedules : PartialModel a msg -> Html Msg
viewRepoSchedules model =
    let
        scheduleModel =
            model.schedulesModel

        actions =
            Just <|
                div [ class "buttons" ]
                    [ a
                        [ class "button"
                        , class "button-with-icon"
                        , class "-outline"
                        , Util.testAttribute "add-repo-secret"
                        , Routes.href <|
                            Routes.AddRepoSecret "native" scheduleModel.org scheduleModel.repo
                        ]
                        [ text "Add Repo Secret"
                        , FeatherIcons.plus
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                        ]
                    ]

        ( noRowsView, rows ) =
            case scheduleModel.schedules of
                Success s ->
                    ( text "No Schedules found for this repo"
                    , schedulesToRows s
                    )

                Failure error ->
                    ( span [ Util.testAttribute "repo-secrets-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No secrets found for this repo, most likely due to not being an admin of the source control repo"

                                        _ ->
                                            "No secrets found for this repo, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No secrets found for this repo, there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( largeLoader, [] )

        cfg =
            Table.Config
                "Repo Secrets"
                "repo-secrets"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div [] [ Table.view cfg ]



{-| secretsToRows : takes list of secrets and produces list of Table rows
-}
schedulesToRows : Schedules -> Table.Rows Schedule Msg
schedulesToRows schedules =
    List.map (\secret -> Table.Row (addKey secret) (renderSchedule )) schedules


{-| tableHeaders : returns table headers for secrets table
-}
tableHeaders : Table.Columns
tableHeaders =
    [ ( Nothing, "" )
    , ( Nothing, "name" )
    , ( Nothing, "key" )
    , ( Nothing, "type" )
    , ( Nothing, "events" )
    , ( Nothing, "images" )
    , ( Nothing, "allow command" )
    ]


{-| renderSecret : takes secret and secret type and renders a table row
-}
renderSchedule : Schedule -> Html Msg
renderSchedule schedule =
    tr [ Util.testAttribute <| "secrets-row" ]
        [ td
            [ attribute "data-label" "name"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "secrets-row-name"
            ]
            [ a [ updateSecretHref schedule ] [ text schedule.name ] ]
        , td
            [ attribute "data-label" "key"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "secrets-row-key"
            ]
            [ text <| schedule.name ]
        , td
            [ attribute "data-label" "type"
            , scope "row"
            , class "break-word"
            ]
            [ text <| schedule.entry ]
        , td
            [ attribute "data-label" "allow command"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Util.boolToYesNo schedule.enabled ]
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
updateSecretHref : Schedule -> Html.Attribute msg
updateSecretHref secret =
    let
        idAsString =
            String.fromInt secret.id
    in
    Routes.href <|
            Routes.Schedule secret.org secret.repo idAsString


-- ADD SECRET


{-| addSecret : takes partial model and renders the Add Secret form
-}
addSchedule : PartialModel a msg -> Html Msg
addSchedule model =
    div [ class "add-schedule", Util.testAttribute "add-schedule" ]
        [ div []
            [  addForm model.secretsModel
            ]
        ]


{-| addForm : renders secret update form for adding a new secret
-}
addForm : Model msg -> Html Msg
addForm scheduleModel =
    let
        secretUpdate =
            scheduleModel.form
    in
    div [ class "secret-form" ]
        [ viewNameInput secretUpdate.name False
        , viewValueInput secretUpdate.entry "Secret Value"
        , viewEnabledCheckbox secretUpdate
        , viewHelp
        , div [ class "form-action" ]
            [ button [ class "button", class "-outline", onClick <| Pages.Schedules.Model.AddSchedule ] [ text "Add" ]
            ]
        ]


{-| addKey : helper to create secret key
-}
addKey : Schedule -> Schedule
addKey schedule =
    let
      idAsString = String.fromInt schedule.id
    in
    { schedule | org = schedule.org ++ "/" ++ schedule.repo ++ "/" ++ idAsString }


-- EDIT SECRET


{-| editSecret : takes partial model and renders secret update form for editing a secret
-}
editSchedule : PartialModel a msg -> Html Msg
editSchedule model =
    case model.schedulesModel.schedule of
        Success _ ->
            div [ class "manage-schedule", Util.testAttribute "manage-schedule" ]
                [ div []
                    [ editForm model.secretsModel
                    ]
                ]

        Failure _ ->
            viewResourceError { resourceLabel = "schedule", testLabel = "schedule" }

        _ ->
            text ""



{-| editForm : renders secret update form for updating a preexisting secret
-}
editForm : Model msg -> Html Msg
editForm scheduleModel =
    let
        scheduleUpdate =
            scheduleModel.form
    in
    div [ class "secret-form", class "edit-form" ]
        [ viewNameInput scheduleUpdate.name True
        , viewValueInput scheduleUpdate.entry "Secret Value (leave blank to make no change)"
        , viewEnabledCheckbox scheduleUpdate
        , viewHelp
        , viewSubmitButtons scheduleModel
        ]
