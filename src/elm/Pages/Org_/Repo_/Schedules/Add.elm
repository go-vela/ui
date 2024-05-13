{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Schedules.Add exposing (Model, Msg, page, view)

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
import Route exposing (Route)
import Route.Path
import Shared
import String.Extra
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela exposing (defaultSchedulePayload)
import View exposing (View)


{-| page : takes user, shared model, route, and returns an add schedule page.
-}
page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


{-| toLayout : takes user, route, model, and passes an add schedule page info to Layouts.
-}
toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "Add Schedule Help"
              , content = "vela add schedule -h"
              , docs = Just "schedule/add"
              }
            , { name = "Add Schedule Example"
              , content =
                    "vela add schedule --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --schedule nightly --entry '0 0 * * *'"
              , docs = Just "schedule/add"
              }
            ]
        }



-- INIT


{-| Model : alias for a model object for an add schedule page.
-}
type alias Model =
    { name : String
    , entry : String
    , enabled : Bool
    , branch : String
    , repoSchedulesAllowed : Bool
    }


{-| init : takes shared model, route, and initializes add schedule page input arguments.
-}
init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { name = ""
      , entry = ""
      , enabled = True
      , branch = ""
      , repoSchedulesAllowed = Util.checkScheduleAllowlist route.params.org route.params.repo shared.velaScheduleAllowlist
      }
    , Effect.none
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = -- SCHEDULES
      AddRepoScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Schedule ))
    | NameOnInput String
    | EntryOnInput String
    | BranchOnInput String
    | EnabledOnClick String
    | SubmitForm


{-| update : takes current models, route, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- SCHEDULES
        AddRepoScheduleResponse response ->
            case response of
                Ok ( _, schedule ) ->
                    ( { model
                        | name = ""
                        , entry = ""
                        , enabled = True
                        , branch = ""
                      }
                    , Effect.addAlertSuccess
                        { content = "Added repo schedule '" ++ schedule.name ++ "'."
                        , addToastIfUnique = True
                        , link = Nothing
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        NameOnInput val ->
            ( { model | name = val }
            , Effect.none
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
            ( model |> (\m -> { m | enabled = Util.yesNoToBool val })
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
            , Effect.addRepoSchedule
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = AddRepoScheduleResponse
                , org = route.params.org
                , repo = route.params.repo
                , name = model.name
                , body = body
                }
            )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns that there are no subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes models, route, and creates the html for an add schedule page.
-}
view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    let
        formDisabled =
            not model.repoSchedulesAllowed

        crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Just <| Route.Path.Org__Repo_ { org = route.params.org, repo = route.params.repo } )
            , ( "Schedules", Just <| Route.Path.Org__Repo__Schedules { org = route.params.org, repo = route.params.repo } )
            , ( "Add", Nothing )
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
                    [ h2 [] [ text <| String.Extra.toTitleCase <| "add repo schedule" ]
                    , if not model.repoSchedulesAllowed then
                        Components.ScheduleForm.viewSchedulesNotAllowedWarning

                      else
                        text ""
                    , div [ class "schedule-form" ]
                        [ Components.Form.viewInputSection
                            { title = Just "Name"
                            , subtitle = Nothing
                            , id_ = "name"
                            , val = model.name
                            , placeholder_ = "Schedule Name"
                            , classList_ = [ ( "schedule-name", True ) ]
                            , rows_ = Nothing
                            , wrap_ = Nothing
                            , msg = NameOnInput
                            , disabled_ = formDisabled
                            }
                        , Components.Form.viewTextareaSection
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
                        , Components.Form.viewInputSection
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
                        , Components.Form.viewButton
                            { id_ = "submit"
                            , msg = SubmitForm
                            , text_ = "Add Schedule"
                            , classList_ = []
                            , disabled_ = formDisabled
                            }
                        ]
                    ]
                ]
            ]
        ]
    }
