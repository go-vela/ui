{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Schedules.View exposing (addSchedule, viewRepoSchedules)

import Errors exposing (viewResourceError)
import FeatherIcons
import Html exposing (Html, a, button, div, h2, span, strong, td, text, tr)
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
import Vela exposing (Org, Repo, Schedule, Schedules, SchedulesModel, SecretType(..))



-- VIEW

{-| viewPreview : renders single schedule item preview
-}
viewPreview : Org -> Repo -> Schedule -> Html msg
viewPreview org repo schedule =
    let
        id =
            String.fromInt schedule.id

        name =
            [ text <| schedule.name ]

        entry =
            [ text schedule.entry ]

        enabled = schedule.enabled

        redeploy =
            [ a [ Routes.href <| Routes.Schedule org repo id ] [ text "Edit" ] ]

        markdown =
            [ div [ class "status", Util.testAttribute "deployment-status", class "-success" ]
                []
            , div [ class "info" ]
                [ div [ class "row -left" ]
                    [ div [ class "id" ] []
                    , div [ class "commit-msg" ] [ strong [] name ]
                    ]
                , div [ class "row" ]
                    [ div [ class "git-info" ]
                        [ div [ class "commit" ] name
                        , text "on"
                        , div [ class "branch" ] entry
                        , text "by"
                        , div [ class "sender" ] [ text <| Util.boolToYesNo schedule.enabled ]
                        ]
                    , div [] redeploy
                    ]
                ]
            ]
    in
    div [ class "build-container", Util.testAttribute "deployment" ]
        [ div [ class "build", class "-success" ] <|
            markdown
        ]


{-| viewRepoSchedules : takes schedules model and renders table for viewing repo schedules
-}
viewRepoSchedules : SchedulesModel -> Org -> Repo -> Html msg
viewRepoSchedules sm org repo =
    let

        actions =
            Just <|
                div [ class "buttons" ]
                    [ a
                        [ class "button"
                        , class "button-with-icon"
                        , class "-outline"
                        , Util.testAttribute "add-repo-schedule"
                        , Routes.href <|
                            Routes.AddSchedule org repo
                        ]
                        [ text "Add Schedule"
                        , FeatherIcons.plus
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                        ]
                    ]

        ( noRowsView, rows ) =
            case sm.schedules of
                Success s ->
                    ( text "No schedules found for this repo"
                    , schedulesToRows org repo s
                    )

                Failure error ->
                    ( span [ Util.testAttribute "repo-schedule-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No schedules found for this repo, most likely due to not being an admin of the source control repo"

                                        _ ->
                                            "No schedules found for this repo, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No schedules found for this repo, there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( largeLoader, [] )

        cfg =
            Table.Config
                "Repo Schedules"
                "repo-schedules"
                noRowsView
                tableHeaders
                rows
                actions
    in
      div [] [Table.view cfg]


{-| schedulesToRows : takes list of schedules and produces list of Table rows
-}
schedulesToRows : Org -> Repo -> Schedules -> Table.Rows Schedule msg
schedulesToRows org repo schedules =
    List.map (\s -> Table.Row (addKey s) (renderSchedule org repo )) schedules


{-| tableHeaders : returns table headers for schedules table
-}
tableHeaders : Table.Columns
tableHeaders =
    [ ( Nothing, "name" )
    , ( Nothing, "entry" )
    , ( Nothing, "enabled" )
    ]


{-| renderSchedule : takes schedule and renders a table row
-}
renderSchedule : Org -> Repo -> Schedule -> Html msg
renderSchedule org repo schedule =
    tr [ Util.testAttribute <| "schedules-row" ]
        [ td
            [ attribute "data-label" "name"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "schedules-row-name"
            ]
            [ a [ updateScheduleHref org repo schedule ] [ text schedule.name ] ]
        , td
            [ attribute "data-label" "entry"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "schedules-row-key"
            ]
            [ text <| schedule.entry ]
        , td
            [ attribute "data-label" "enabled"
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


{-| updateScheduleHref : takes schedule and returns href link for routing to view/edit schedule page
-}
updateScheduleHref : Org -> Repo -> Schedule -> Html.Attribute msg
updateScheduleHref org repo s =
    let
        idAsString =
            String.fromInt s.id
    in
    Routes.href <|
            Routes.Schedule org repo idAsString


{-| addSchedule : takes partial model and renders the Add schedule form
-}
addSchedule : PartialModel a msg -> Html Msg
addSchedule model =
    div [ class "add-schedule", Util.testAttribute "add-schedule" ]
        [ div []
            [  addForm model.schedulesModel
            ]
        ]


{-| addForm : renders schedule update form for adding a new schedule
-}
addForm : Model msg -> Html Msg
addForm scheduleModel =
    let
        s =
            scheduleModel.form
    in
    div [ class "schedule-form" ]
        [ viewNameInput s.name False
        , viewValueInput s.entry "cron expression (0 0 * * *)"
        , viewEnabledCheckbox s
        , viewHelp
        , div [ class "form-action" ]
            [ button [ class "button", class "-outline", onClick <| Pages.Schedules.Model.AddSchedule ] [ text "Add" ]
            ]
        ]


{-| addKey : helper to create Schedule key
-}
addKey : Schedule -> Schedule
addKey schedule =
    let
      idAsString = String.fromInt schedule.id
    in
    { schedule | org = schedule.org ++ "/" ++ schedule.repo ++ "/" ++ idAsString }


{-| editSchedule : takes partial model and renders schedule update form for editing a schedule
-}
editSchedule : PartialModel a msg -> Html Msg
editSchedule model =
    case model.schedulesModel.schedule of
        Success _ ->
            div [ class "manage-schedule", Util.testAttribute "manage-schedule" ]
                [ div []
                    [ editForm model.schedulesModel
                    ]
                ]

        Failure _ ->
            viewResourceError { resourceLabel = "schedule", testLabel = "schedule" }

        _ ->
            text ""



{-| editForm : renders schedule update form for updating a preexisting schedule
-}
editForm : Model msg -> Html Msg
editForm scheduleModel =
    let
        scheduleUpdate =
            scheduleModel.form
    in
    div [ class "schedule-form", class "edit-form" ]
        [ viewNameInput scheduleUpdate.name True
        , viewValueInput scheduleUpdate.entry "cron expression (0 0 * * *)"
        , viewEnabledCheckbox scheduleUpdate
        , viewHelp
        , viewSubmitButtons scheduleModel
        ]
