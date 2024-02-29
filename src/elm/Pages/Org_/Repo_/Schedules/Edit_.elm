{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Schedules.Edit_ exposing (Model, Msg, page, view)

import Auth
import Components.Crumbs
import Components.Form
import Components.Nav
import Components.ScheduleForm
import Effect exposing (Effect)
import Html exposing (div, em, h2, main_, span, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import String.Extra
import Utils.Helpers as Util
import Vela exposing (defaultSchedulePayload)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String, name : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String, name : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "View Schedule"
              , content =
                    "vela view schedule --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --name "
                        ++ route.params.name
              , docs = Just "schedule/view"
              }
            , { name = "Update Schedule"
              , content =
                    "vela update schedule --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --name "
                        ++ route.params.name
              , docs = Just "schedule/update"
              }
            , { name = "Delete Schedule"
              , content =
                    "vela remove schedule --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --name "
                        ++ route.params.name
              , docs = Just "schedule/remove"
              }
            ]
        }



-- INIT


type alias Model =
    { schedule : WebData Vela.Schedule
    , name : String
    , entry : String
    , enabled : Bool
    , branch : String
    , confirmingDelete : Bool
    , repoSchedulesAllowed : Bool
    }


init : Shared.Model -> Route { org : String, repo : String, name : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { schedule = RemoteData.Loading
      , name = ""
      , entry = ""
      , enabled = True
      , branch = ""
      , confirmingDelete = False
      , repoSchedulesAllowed = Util.checkScheduleAllowlist route.params.org route.params.repo shared.velaScheduleAllowlist
      }
    , if Util.checkScheduleAllowlist route.params.org route.params.repo shared.velaScheduleAllowlist then
        Effect.getRepoSchedule
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetRepoScheduleResponse
            , org = route.params.org
            , repo = route.params.repo
            , name = route.params.name
            }

      else
        Effect.none
    )



-- UPDATE


type Msg
    = NoOp
      -- SCHEDULES
    | GetRepoScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Schedule ))
    | UpdateRepoScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Schedule ))
    | DeleteScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | EntryOnInput String
    | BranchOnInput String
    | EnabledOnClick String
    | SubmitForm
    | ClickDelete
    | CancelDelete
    | ConfirmDelete


update : Shared.Model -> Route { org : String, repo : String, name : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        -- SCHEDULES
        GetRepoScheduleResponse response ->
            case response of
                Ok ( _, schedule ) ->
                    ( { model
                        | schedule = RemoteData.Success schedule
                        , name = schedule.name
                        , entry = schedule.entry
                        , enabled = schedule.enabled
                        , branch = schedule.branch
                      }
                    , Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        UpdateRepoScheduleResponse response ->
            case response of
                Ok ( _, schedule ) ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = schedule.name ++ " updated in repo schedules."
                        , addToastIfUnique = True
                        , link = Nothing
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        DeleteScheduleResponse response ->
            case response of
                Ok ( _, result ) ->
                    ( model
                    , Effect.batch
                        [ Effect.addAlertSuccess
                            { content = result
                            , addToastIfUnique = True
                            , link = Nothing
                            }
                        , Effect.pushPath <|
                            Route.Path.Org_Repo_Schedules
                                { org = route.params.org
                                , repo = route.params.repo
                                }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        EntryOnInput val ->
            ( { model | entry = val }
            , Effect.none
            )

        BranchOnInput val ->
            ( { model | branch = val }
            , Effect.none
            )

        EnabledOnClick val ->
            ( model
                |> (\m -> { m | enabled = Util.yesNoToBool val })
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    { defaultSchedulePayload
                        | org = Just route.params.org
                        , repo = Just route.params.repo
                        , name = Util.stringToMaybe model.name
                        , entry = Util.stringToMaybe model.entry
                        , enabled = Just model.enabled
                        , branch = Just model.branch
                    }

                body =
                    Http.jsonBody <| Vela.encodeSchedulePayload payload
            in
            ( model
            , Effect.updateRepoSchedule
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateRepoScheduleResponse
                , org = route.params.org
                , repo = route.params.repo
                , name = model.name
                , body = body
                }
            )

        ClickDelete ->
            ( { model | confirmingDelete = True }
            , Effect.none
            )

        CancelDelete ->
            ( { model | confirmingDelete = False }
            , Effect.none
            )

        ConfirmDelete ->
            ( { model | confirmingDelete = False }
            , Effect.deleteRepoSchedule
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = DeleteScheduleResponse
                , org = route.params.org
                , repo = route.params.repo
                , name = route.params.name
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, name : String } -> Model -> View Msg
view shared route model =
    let
        schedulesAllowed =
            Util.checkScheduleAllowlist route.params.org route.params.repo shared.velaScheduleAllowlist

        formDisabled =
            not schedulesAllowed || (not <| RemoteData.isSuccess model.schedule)

        crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Just <| Route.Path.Org_Repo_ { org = route.params.org, repo = route.params.repo } )
            , ( "Schedules", Just <| Route.Path.Org_Repo_Schedules { org = route.params.org, repo = route.params.repo } )
            , ( "Edit", Nothing )
            , ( route.params.name
              , Just <|
                    Route.Path.Org_Repo_SchedulesEdit_
                        { org = route.params.org
                        , repo = route.params.repo
                        , name = route.params.name
                        }
              )
            ]
    in
    { title = "Add Schedule"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ class "manage-schedule", Util.testAttribute "manage-schedule" ]
                [ div []
                    [ h2 [] [ text <| String.Extra.toTitleCase <| "update repo schedule" ]
                    , if not model.repoSchedulesAllowed then
                        Components.ScheduleForm.viewSchedulesNotAllowedWarning

                      else
                        text ""
                    , div [ class "schedule-form" ]
                        [ Components.Form.viewInput
                            { title = Just "Name"
                            , subtitle = Nothing
                            , id_ = "name"
                            , val = RemoteData.unwrap "" .name model.schedule
                            , placeholder_ =
                                if model.repoSchedulesAllowed then
                                    "Loading..."

                                else
                                    "Schedule Name"
                            , classList_ = [ ( "schedule-name", True ) ]
                            , rows_ = Nothing
                            , wrap_ = Nothing
                            , msg = \_ -> NoOp
                            , disabled_ = True
                            }
                        , Components.Form.viewTextarea
                            { title = Just "Cron Expression"
                            , subtitle = Just <| Components.ScheduleForm.viewCronHelp shared.time
                            , id_ = "entry"
                            , val = model.entry
                            , placeholder_ = "0 0 * * * (runs at 12:00 AM in UTC)"
                            , classList_ = [ ( "schedule-cron", True ) ]
                            , rows_ = Just 2
                            , wrap_ = Just "soft"
                            , msg = EntryOnInput
                            , disabled_ = formDisabled
                            }
                        , Components.ScheduleForm.viewEnabledInput
                            { msg = EnabledOnClick
                            , value = model.enabled
                            , disabled_ = formDisabled
                            }
                        , Components.Form.viewInput
                            { title = Just "Branch"
                            , subtitle =
                                Just <|
                                    span
                                        [ class "field-description" ]
                                        [ em [] [ text "(Leave blank to use default branch)" ]
                                        ]
                            , id_ = "branch-name"
                            , val = model.branch
                            , placeholder_ = "Branch Name"
                            , classList_ = [ ( "branch-name", True ) ]
                            , rows_ = Nothing
                            , wrap_ = Nothing
                            , msg = BranchOnInput
                            , disabled_ = formDisabled
                            }
                        , Components.ScheduleForm.viewHelp shared.velaDocsURL
                        , div [ class "buttons" ]
                            [ Components.Form.viewButton
                                { msg = SubmitForm
                                , text_ = "Submit"
                                , classList_ = []
                                , disabled_ = formDisabled
                                , id_ = "submit"
                                }
                            , if not model.confirmingDelete then
                                Components.Form.viewButton
                                    { msg = ClickDelete
                                    , text_ = "Delete"
                                    , classList_ = []
                                    , disabled_ = formDisabled
                                    , id_ = "delete"
                                    }

                              else
                                Components.Form.viewButton
                                    { msg = CancelDelete
                                    , text_ = "Cancel"
                                    , classList_ = []
                                    , disabled_ = formDisabled
                                    , id_ = "delete-cancel"
                                    }
                            , if model.confirmingDelete then
                                Components.Form.viewButton
                                    { msg = ConfirmDelete
                                    , text_ = "Confirm"
                                    , classList_ = [ ( "-secret-delete-confirm", True ) ]
                                    , disabled_ = formDisabled
                                    , id_ = "delete-confirm"
                                    }

                              else
                                text ""
                            ]
                        ]
                    ]
                ]
            ]
        ]
    }
