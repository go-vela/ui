{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Settings exposing (Model, Msg, page, view)

import Auth
import Components.Form
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (Html, a, br, button, div, em, h2, img, input, label, p, section, small, span, text, textarea)
import Html.Attributes exposing (alt, attribute, class, classList, disabled, for, href, id, readonly, rows, src, type_, value, wrap)
import Html.Events exposing (onClick, onInput)
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import Pages.Account.SourceRepos exposing (Msg(..))
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors as Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela exposing (defaultRepoPayload)
import View exposing (View)


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


toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Repo
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "View Repo"
              , content =
                    "vela view repo --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
              , docs = Just "repo/view"
              }
            , { name = "Update Repo Help"
              , content = "vela update repo -h"
              , docs = Just "repo/update"
              }
            , { name = "Update Repo Example"
              , content =
                    "vela update repo --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
              , docs = Just "repo/update"
              }
            , { name = "Repair Repo"
              , content =
                    "vela repair repo --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
              , docs = Just "repo/repair"
              }
            , { name = "Chown Repo"
              , content =
                    "vela chown repo--org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
              , docs = Just "repo/chown"
              }
            ]
        , crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        }



-- INIT


type alias Model =
    { repo : WebData Vela.Repository
    , inLimit : Maybe Int
    , inCounter : Maybe Int
    , inTimeout : Maybe Int
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { repo = RemoteData.Loading
      , inLimit = Nothing
      , inCounter = Nothing
      , inTimeout = Nothing
      }
    , Effect.getRepo
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetRepoResponse
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = --REPO
      GetRepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
    | GetRepoRefreshResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
    | UpdateRepoResponse { field : Vela.RepoFieldUpdate } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
    | EnableRepo { repo : Vela.Repository }
    | EnableRepoResponse { repo : Vela.Repository } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
    | DisableRepo { repo : Vela.Repository }
    | DisableRepoResponse { repo : Vela.Repository } (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RepairRepo { repo : Vela.Repository }
    | RepairRepoResponse { repo : Vela.Repository } (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | ChownRepo { repo : Vela.Repository }
    | ChownRepoResponse { repo : Vela.Repository } (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | AllowEventsUpdate { allowEvents : Vela.AllowEvents, event : Vela.AllowEventsField } Bool
    | AccessUpdate String
    | ForkPolicyUpdate String
    | BuildLimitOnInput String
    | BuildLimitUpdate Int
    | BuildTimeoutOnInput String
    | BuildTimeoutUpdate Int
    | BuildCounterOnInput String
    | BuildCounterUpdate Int
    | PipelineTypeUpdate String
      -- ALERTS
    | AddAlertCopiedToClipboard String
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- REPO
        GetRepoResponse response ->
            case response of
                Ok ( _, repo ) ->
                    ( { model | repo = RemoteData.succeed repo }
                    , Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        GetRepoRefreshResponse response ->
            case response of
                Ok ( _, repo ) ->
                    ( { model
                        | repo =
                            RemoteData.succeed
                                { repo
                                    | enabled =
                                        RemoteData.unwrap repo.enabled (\repo_ -> repo_.enabled) model.repo
                                }
                      }
                    , Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        UpdateRepoResponse options response ->
            case response of
                Ok ( _, repo ) ->
                    let
                        responseConfig =
                            Vela.repoFieldUpdateToResponseConfig options.field
                    in
                    ( { model | repo = RemoteData.succeed repo }
                    , Effect.addAlertSuccess
                        { content = responseConfig.successAlert repo
                        , addToastIfUnique = False
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

        EnableRepo options ->
            let
                payload =
                    Vela.buildRepoPayload options.repo

                body =
                    Http.jsonBody <| Vela.encodeEnableRepository payload
            in
            options.repo
                |> (\repo ->
                        ( { model
                            | repo =
                                RemoteData.succeed
                                    { repo
                                        | enabled = Vela.Enabling
                                    }
                          }
                        , Effect.enableRepo
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = EnableRepoResponse { repo = repo }
                            , body = body
                            }
                        )
                   )

        EnableRepoResponse options response ->
            case response of
                Ok ( _, repo ) ->
                    ( { model
                        | repo =
                            RemoteData.succeed
                                { repo
                                    | active = True
                                    , enabled = Vela.Enabled
                                }
                      }
                    , Effect.addAlertSuccess
                        { content = "Repo " ++ repo.full_name ++ " enabled."
                        , addToastIfUnique = False
                        , link = Nothing
                        }
                    )

                Err error ->
                    let
                        repo =
                            options.repo
                    in
                    case error of
                        Http.Detailed.BadStatus metadata _ ->
                            case metadata.statusCode of
                                409 ->
                                    ( { model
                                        | repo =
                                            RemoteData.succeed
                                                { repo
                                                    | active = True
                                                    , enabled = Vela.Enabled
                                                }
                                      }
                                    , Effect.addAlertSuccess
                                        { content = "Repo " ++ repo.full_name ++ " enabled."
                                        , addToastIfUnique = False
                                        , link = Nothing
                                        }
                                    )

                                _ ->
                                    ( { model
                                        | repo = RemoteData.succeed { repo | enabled = Vela.Failed }
                                      }
                                    , Effect.handleHttpError
                                        { error = error
                                        , shouldShowAlertFn = Errors.showAlertAlways
                                        }
                                    )

                        _ ->
                            ( { model
                                | repo = RemoteData.succeed { repo | enabled = Vela.Failed }
                              }
                            , Effect.handleHttpError
                                { error = error
                                , shouldShowAlertFn = Errors.showAlertAlways
                                }
                            )

        DisableRepo options ->
            let
                repo =
                    options.repo
            in
            case options.repo.enabled of
                Vela.Enabled ->
                    ( { model
                        | repo =
                            RemoteData.succeed
                                { repo
                                    | enabled = Vela.ConfirmDisable
                                }
                      }
                    , Effect.none
                    )

                Vela.ConfirmDisable ->
                    ( { model
                        | repo =
                            RemoteData.succeed
                                { repo
                                    | enabled = Vela.Disabling
                                }
                      }
                    , Effect.disableRepo
                        { baseUrl = shared.velaAPIBaseURL
                        , session = shared.session
                        , onResponse = DisableRepoResponse { repo = repo }
                        , org = route.params.org
                        , repo = route.params.repo
                        }
                    )

                _ ->
                    ( model
                    , Effect.none
                    )

        DisableRepoResponse options response ->
            let
                repo =
                    options.repo
            in
            case response of
                Ok ( _, result ) ->
                    ( { model
                        | repo =
                            RemoteData.succeed
                                { repo
                                    | active = False
                                    , enabled = Vela.Disabled
                                }
                      }
                    , Effect.addAlertSuccess
                        { content = "Repo " ++ repo.full_name ++ " disabled."
                        , addToastIfUnique = False
                        , link = Nothing
                        }
                    )

                Err error ->
                    ( { model
                        | repo =
                            RemoteData.succeed
                                { repo
                                    | enabled = Vela.Failed
                                }
                      }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        ChownRepo options ->
            let
                currentUser =
                    RemoteData.unwrap ""
                        (\user -> " (" ++ user.name ++ ")")
                        shared.user
            in
            ( model
            , Effect.chownRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = ChownRepoResponse options
                , org = route.params.org
                , repo = route.params.repo
                }
            )

        ChownRepoResponse options response ->
            let
                currentUser =
                    RemoteData.unwrap ""
                        (\user -> " (" ++ user.name ++ ")")
                        shared.user
            in
            case response of
                Ok ( _, result ) ->
                    ( model
                    , Effect.batch
                        [ Effect.getRepo
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = GetRepoResponse
                            , org = route.params.org
                            , repo = route.params.repo
                            }
                        , Effect.addAlertSuccess
                            { content = "Ownership of " ++ options.repo.full_name ++ " transferred to the current user" ++ currentUser ++ ". You are now the owner."
                            , addToastIfUnique = False
                            , link = Nothing
                            }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        RepairRepo options ->
            ( model
            , Effect.repairRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = RepairRepoResponse options
                , org = route.params.org
                , repo = route.params.repo
                }
            )

        RepairRepoResponse options response ->
            case response of
                Ok ( _, result ) ->
                    ( model
                    , Effect.batch
                        [ Effect.getRepo
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = GetRepoResponse
                            , org = route.params.org
                            , repo = route.params.repo
                            }
                        , Effect.addAlertSuccess
                            { content = "Repo " ++ options.repo.full_name ++ " repaired. Webhook successfully recreated."
                            , addToastIfUnique = False
                            , link = Nothing
                            }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        AllowEventsUpdate options val ->
            let
                payload =
                    { defaultRepoPayload
                        | allowEvents =
                            Just (Vela.setAllowEvents options options.event val).allowEvents
                    }

                body =
                    Http.jsonBody <| Vela.encodeRepoPayload payload
            in
            ( model
            , Effect.updateRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateRepoResponse { field = Vela.AllowEvents_ options.event }
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        AccessUpdate val ->
            let
                payload =
                    { defaultRepoPayload
                        | visibility = Just val
                    }

                body =
                    Http.jsonBody <| Vela.encodeRepoPayload payload
            in
            ( model
            , Effect.updateRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateRepoResponse { field = Vela.Visibility }
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        ForkPolicyUpdate val ->
            let
                payload =
                    { defaultRepoPayload
                        | approve_build = Just val
                    }

                body =
                    Http.jsonBody <| Vela.encodeRepoPayload payload
            in
            ( model
            , Effect.updateRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateRepoResponse { field = Vela.ApproveBuild }
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        BuildLimitOnInput val ->
            ( { model
                | inLimit = Just <| Maybe.withDefault 0 <| String.toInt val
              }
            , Effect.none
            )

        BuildLimitUpdate val ->
            let
                payload =
                    { defaultRepoPayload
                        | limit = Just val
                    }

                body =
                    Http.jsonBody <| Vela.encodeRepoPayload payload
            in
            ( model
            , Effect.updateRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateRepoResponse { field = Vela.Limit }
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        BuildTimeoutOnInput val ->
            let
                newTimeout =
                    case String.toInt val of
                        Just t ->
                            Just t

                        Nothing ->
                            Just 0
            in
            ( { model | inTimeout = newTimeout }
            , Effect.none
            )

        BuildTimeoutUpdate val ->
            let
                payload =
                    { defaultRepoPayload
                        | timeout = Just val
                    }

                body =
                    Http.jsonBody <| Vela.encodeRepoPayload payload
            in
            ( model
            , Effect.updateRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateRepoResponse { field = Vela.Timeout }
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        BuildCounterOnInput val ->
            let
                newCounter =
                    case String.toInt val of
                        Just t ->
                            Just t

                        Nothing ->
                            Just 0
            in
            ( { model | inCounter = newCounter }
            , Effect.none
            )

        BuildCounterUpdate val ->
            let
                payload =
                    { defaultRepoPayload
                        | counter = Just val
                    }

                body =
                    Http.jsonBody <| Vela.encodeRepoPayload payload
            in
            ( model
            , Effect.updateRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateRepoResponse { field = Vela.Counter }
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        PipelineTypeUpdate val ->
            let
                payload =
                    { defaultRepoPayload
                        | pipeline_type = Just val
                    }

                body =
                    Http.jsonBody <| Vela.encodeRepoPayload payload
            in
            ( model
            , Effect.updateRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateRepoResponse { field = Vela.PipelineType }
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        -- ALERTS
        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess
                { content = "'" ++ contentCopied ++ "' copied to clipboard."
                , addToastIfUnique = False
                , link = Nothing
                }
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetRepoRefreshResponse
                , org = route.params.org
                , repo = route.params.repo
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = "Settings"
    , body =
        [ case model.repo of
            RemoteData.Success repo ->
                div [ class "repo-settings", Util.testAttribute "repo-settings" ]
                    [ viewAllowEvents shared repo AllowEventsUpdate
                    , viewAccess repo AccessUpdate
                    , viewForkPolicy repo ForkPolicyUpdate
                    , viewLimit shared repo model.inLimit BuildLimitUpdate BuildLimitOnInput
                    , viewTimeout repo model.inTimeout BuildTimeoutUpdate BuildTimeoutOnInput
                    , viewBuildCounter repo model.inCounter BuildCounterUpdate BuildCounterOnInput
                    , viewBadge shared repo AddAlertCopiedToClipboard
                    , viewAdminActions repo DisableRepo EnableRepo ChownRepo RepairRepo
                    , viewPipelineType repo PipelineTypeUpdate
                    ]

            _ ->
                text ""
        ]
    }


{-| viewAllowEvents : takes shared model and repo and renders the settings category for updating repo allow events
-}
viewAllowEvents : Shared.Model -> Vela.Repository -> ({ allowEvents : Vela.AllowEvents, event : Vela.AllowEventsField } -> Bool -> msg) -> Html msg
viewAllowEvents shared repo msg =
    section [ class "settings", Util.testAttribute "repo-settings-events" ]
        ([ h2 [ class "settings-title" ] [ text "Webhook Events" ]
         , p [ class "settings-description" ]
            [ text "Control which events on Git will trigger Vela pipelines."
            , br [] []
            , em [] [ text "Active repositories must have at least one event enabled." ]
            ]
         ]
            ++ Components.Form.viewAllowEvents
                shared
                { msg = msg
                , allowEvents = repo.allowEvents
                , disabled_ = False
                }
        )


{-| viewAccess : takes shared model and repo and renders the settings category for updating repo access
-}
viewAccess : Vela.Repository -> (String -> msg) -> Html msg
viewAccess repo msg =
    section [ class "settings", Util.testAttribute "repo-settings-access" ]
        [ h2 [ class "settings-title" ] [ text "Access" ]
        , p [ class "settings-description" ] [ text "Change who can access build information." ]
        , div [ class "form-controls", class "-stack" ]
            [ Components.Form.viewRadio
                { title = "Private"
                , subtitle = Just (text "(restricted to those with repository access)")
                , value = repo.visibility
                , field = "private"
                , msg = msg "private"
                , disabled_ = False
                , id_ = "access-private"
                }
            , Components.Form.viewRadio
                { title = "Any"
                , subtitle = Just (text "(anyone with access to this Vela instance)")
                , value = repo.visibility
                , field = "public"
                , msg = msg "public"
                , disabled_ = False
                , id_ = "access-public"
                }
            ]
        ]


{-| viewForkPolicy : takes model and repo and renders the settings category for updating repo fork policy
-}
viewForkPolicy : Vela.Repository -> (String -> msg) -> Html msg
viewForkPolicy repo msg =
    section [ class "settings", Util.testAttribute "repo-settings-fork-policy" ]
        [ h2 [ class "settings-title" ] [ text "Outside Contributor Permissions" ]
        , p [ class "settings-description" ] [ text "Change which pull request builds from forks need approval to run a build." ]
        , div [ class "form-controls", class "-stack" ]
            [ Components.Form.viewRadio
                { title = "Always Require Admin Approval"
                , subtitle = Just (text "(repository admin must approve all builds from outside contributors)")
                , value = repo.approve_build
                , field = "fork-always"
                , msg = msg "fork-always"
                , disabled_ = False
                , id_ = "policy-fork-always"
                }
            , Components.Form.viewRadio
                { title = "Require Admin Approval When Contributor Is Read Only"
                , subtitle = Just (text "(repository admin must approve all builds from outside contributors with read-only access to the repo)")
                , value = repo.approve_build
                , field = "fork-no-write"
                , msg = msg "fork-no-write"
                , disabled_ = False
                , id_ = "policy-fork-no-write"
                }
            , Components.Form.viewRadio
                { title = "Require Admin Approval for First Time Contributors"
                , subtitle = Just (text "(repository admin must approve all builds from outside contributors who have not contributed to the repo before)")
                , value = repo.approve_build
                , field = "first-time"
                , msg = msg "first-time"
                , disabled_ = False
                , id_ = "policy-first-time"
                }
            , Components.Form.viewRadio
                { title = "Never Require Admin Approval"
                , subtitle = Just (text "(any outside contributor can run a PR build)")
                , value = repo.approve_build
                , field = "never"
                , msg = msg "never"
                , disabled_ = False
                , id_ = "policy-never"
                }
            ]
        ]


{-| viewLimit : takes model and repo and renders the settings category for updating repo build limit
-}
viewLimit : Shared.Model -> Vela.Repository -> Maybe Int -> (Int -> msg) -> (String -> msg) -> Html msg
viewLimit shared repo inLimit clickMsg inputMsg =
    section [ class "settings", Util.testAttribute "repo-settings-limit" ]
        [ h2 [ class "settings-title" ] [ text "Build Limit" ]
        , p [ class "settings-description" ] [ text "Concurrent builds (pending or running) that exceed this limit will be stopped." ]
        , div [ class "form-controls" ]
            [ viewLimitInput shared repo inLimit inputMsg
            , viewUpdateLimit shared repo inLimit <| clickMsg <| Maybe.withDefault 0 inLimit
            ]
        , viewLimitWarning shared.velaMaxBuildLimit inLimit
        ]


{-| viewLimitInput : takes repo, user input, and button action and renders the text input for updating build limit.
-}
viewLimitInput : Shared.Model -> Vela.Repository -> Maybe Int -> (String -> msg) -> Html msg
viewLimitInput shared repo inLimit inputMsg =
    div [ class "form-control", Util.testAttribute "repo-limit" ]
        [ input
            [ id <| "repo-limit"
            , onInput inputMsg
            , type_ "number"
            , Html.Attributes.min "1"
            , Html.Attributes.max <| String.fromInt shared.velaMaxBuildLimit
            , value <| String.fromInt <| Maybe.withDefault repo.limit inLimit
            ]
            []
        , label [ class "form-label", for "repo-limit" ] [ text "limit" ]
        ]


{-| viewUpdateLimit : takes maybe int of user entered limit and current repo limit and renders the button to submit the update.
-}
viewUpdateLimit : Shared.Model -> Vela.Repository -> Maybe Int -> msg -> Html msg
viewUpdateLimit shared repo inLimit msg =
    case inLimit of
        Just _ ->
            button
                [ classList
                    [ ( "button", True )
                    , ( "-outline", True )
                    ]
                , onClick msg
                , disabled <| not <| validLimit shared.velaMaxBuildLimit inLimit repo <| Just repo.limit
                ]
                [ text "update" ]

        _ ->
            text ""


{-| viewLimitWarning : takes maybe string of user entered limit and renders a disclaimer on updating the build limit.
-}
viewLimitWarning : Int -> Maybe Int -> Html msg
viewLimitWarning maxLimit inLimit =
    case inLimit of
        Just _ ->
            p [ class "notice" ]
                [ text "Disclaimer: it is highly recommended to optimize your pipeline before increasing this value. Limits must also lie between 1 and "
                , text <| String.fromInt maxLimit
                , text "."
                ]

        _ ->
            text ""


{-| validLimit : takes maybe string of user entered limit and returns whether or not it is a valid update.
-}
validLimit : Int -> Maybe Int -> Vela.Repository -> Maybe Int -> Bool
validLimit maxLimit inLimit _ repoLimit =
    case inLimit of
        Just t ->
            if t >= 1 && t <= maxLimit then
                case repoLimit of
                    Just ti ->
                        t /= ti

                    Nothing ->
                        True

            else
                False

        Nothing ->
            False


{-| viewTimeout : takes model and repo and renders the settings category for updating repo build timeout
-}
viewTimeout : Vela.Repository -> Maybe Int -> (Int -> msg) -> (String -> msg) -> Html msg
viewTimeout repo inTimeout clickMsg inputMsg =
    section [ class "settings", Util.testAttribute "repo-settings-timeout" ]
        [ h2 [ class "settings-title" ] [ text "Build Timeout" ]
        , p [ class "settings-description" ] [ text "Builds that reach this timeout setting will be stopped." ]
        , div [ class "form-controls" ]
            [ viewTimeoutInput repo inTimeout inputMsg
            , case inTimeout of
                Just _ ->
                    button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| clickMsg <| Maybe.withDefault 0 inTimeout
                        , disabled <| not <| validTimeout inTimeout <| Just repo.timeout
                        ]
                        [ text "update" ]

                _ ->
                    text ""
            ]
        , case inTimeout of
            Just _ ->
                p [ class "notice" ]
                    [ text "Disclaimer: if you are experiencing build timeouts, it is highly recommended to optimize your pipeline before increasing this value. Timeouts must also lie between 1 and 90 minutes."
                    ]

            Nothing ->
                text ""
        ]


{-| viewTimeoutInput : takes repo, user input, and button action and renders the text input for updating build timeout.
-}
viewTimeoutInput : Vela.Repository -> Maybe Int -> (String -> msg) -> Html msg
viewTimeoutInput repo inTimeout inputMsg =
    div [ class "form-control", Util.testAttribute "repo-timeout" ]
        [ input
            [ id <| "repo-timeout"
            , onInput inputMsg
            , type_ "number"
            , Html.Attributes.min "1"
            , Html.Attributes.max "90"
            , value <| String.fromInt <| Maybe.withDefault repo.timeout inTimeout
            ]
            []
        , label [ class "form-label", for "repo-timeout" ] [ text "minutes" ]
        ]


{-| validTimeout : takes maybe string of user entered timeout and returns whether or not it is a valid update.
-}
validTimeout : Maybe Int -> Maybe Int -> Bool
validTimeout inTimeout repoTimeout =
    case inTimeout of
        Just t ->
            if t >= 1 && t <= 90 then
                case repoTimeout of
                    Just ti ->
                        t /= ti

                    Nothing ->
                        True

            else
                False

        Nothing ->
            False


{-| viewBuildCounter : takes model and repo and renders the settings category for updating repo build counter
-}
viewBuildCounter : Vela.Repository -> Maybe Int -> (Int -> msg) -> (String -> msg) -> Html msg
viewBuildCounter repo inCounter clickMsg inputMsg =
    section [ class "settings", Util.testAttribute "repo-settings-counter" ]
        [ h2 [ class "settings-title" ] [ text "Build Counter" ]
        , p [ class "settings-description" ] [ text "Builds increment based off this number." ]
        , div [ class "form-controls" ]
            [ viewCounterInput repo inCounter inputMsg
            , viewUpdateCounter inCounter repo repo.counter <| clickMsg <| Maybe.withDefault 0 inCounter
            ]
        , viewCounterWarning inCounter
        ]


{-| viewCounterInput : takes repo, user input, and button action and renders the text input for updating build counter.
-}
viewCounterInput : Vela.Repository -> Maybe Int -> (String -> msg) -> Html msg
viewCounterInput repo inCounter inputMsg =
    div [ class "form-control", Util.testAttribute "repo-counter" ]
        [ input
            [ id <| "repo-counter"
            , onInput inputMsg
            , type_ "number"
            , Html.Attributes.min <| String.fromInt <| repo.counter
            , value <| String.fromInt <| Maybe.withDefault repo.counter inCounter
            ]
            []
        , label [ class "form-label", for "repo-counter" ] [ text "count" ]
        ]


{-| viewUpdateCounter : takes maybe int of user entered counter and current repo counter and renders the button to submit the update.
-}
viewUpdateCounter : Maybe Int -> Vela.Repository -> Int -> msg -> Html msg
viewUpdateCounter inCounter repo repoCounter msg =
    case inCounter of
        Just _ ->
            button
                [ classList
                    [ ( "button", True )
                    , ( "-outline", True )
                    ]
                , onClick msg
                , disabled <| not <| validCounter inCounter repo <| Just repoCounter
                ]
                [ text "update" ]

        _ ->
            text ""


{-| validCounter : takes maybe string of user entered counter and returns whether or not it is a valid update.
-}
validCounter : Maybe Int -> Vela.Repository -> Maybe Int -> Bool
validCounter inCounter repo repoCounter =
    case inCounter of
        Just t ->
            if t >= repo.counter then
                case repoCounter of
                    Just ti ->
                        t /= ti

                    Nothing ->
                        True

            else
                False

        Nothing ->
            False


{-| viewCounterWarning : takes maybe string of user entered counter and renders a disclaimer on updating the build counter.
-}
viewCounterWarning : Maybe Int -> Html msg
viewCounterWarning inCounter =
    case inCounter of
        Just _ ->
            p [ class "notice" ]
                [ text "Disclaimer: Incrementing the build counter can not be reversed. Updating this value will start future builds from this value as the build number"
                ]

        Nothing ->
            text ""


{-| viewBadge : takes repo and renders a section for getting your build status badge
-}
viewBadge : Shared.Model -> Vela.Repository -> (String -> msg) -> Html msg
viewBadge shared repo copyMsg =
    let
        badgeURL =
            String.join "/" [ shared.velaAPIBaseURL, "badge", repo.org, repo.name, "status.svg" ]

        buildURL =
            String.join "/" [ shared.velaUIBaseURL, repo.org, repo.name ]

        mdCode =
            "[![Build Status](" ++ badgeURL ++ ")](" ++ buildURL ++ ")"
    in
    section [ class "settings", Util.testAttribute "repo-settings-badge" ]
        [ h2 [ class "settings-title" ] [ text "Status Badge" ]
        , p [ class "settings-description" ]
            [ text "Show off your build status."
            , br [] []
            , em [] [ text "Uses the default branch on your repository." ]
            ]
        , div []
            [ p [ class "build-badge" ]
                [ img [ alt "build status badge", src badgeURL ] [] ]
            , text "Markdown"
            , div [ class "form-controls", class "-no-x-pad" ]
                [ textarea
                    [ class "form-control"
                    , class "copy-display"
                    , class "-is-expanded"
                    , attribute "aria-label" "status badge markdown code"
                    , rows 2
                    , readonly True
                    , wrap "soft"
                    ]
                    [ text mdCode ]
                , button
                    [ class "copy-button"
                    , class "button"
                    , class "-icon"
                    , class "-white"
                    , attribute "data-clipboard-text" mdCode
                    , attribute "aria-label" "copy status badge markdown code"
                    , Util.testAttribute "copy-md"
                    , onClick <| copyMsg mdCode
                    ]
                    [ FeatherIcons.copy
                        |> FeatherIcons.withSize 18
                        |> FeatherIcons.toHtml []
                    ]
                ]
            , small []
                [ text "To customize branch, "
                , a [ href <| shared.velaDocsURL ++ "/usage/badge/" ]
                    [ text "see our Badges documentation"
                    ]
                , text "."
                ]
            ]
        ]


{-| viewAdminActions : takes admin actions and repo and returns view of the repo admin actions.
-}
viewAdminActions : Vela.Repository -> ({ repo : Vela.Repository } -> msg) -> ({ repo : Vela.Repository } -> msg) -> ({ repo : Vela.Repository } -> msg) -> ({ repo : Vela.Repository } -> msg) -> Html msg
viewAdminActions repo disableRepoMsg enableRepoMsg chownRepoMsg repairRepoMsg =
    let
        enabledDetails =
            if disableable repo.enabled then
                ( "Disable Repository", "This will delete the Vela webhook from this repository." )

            else
                ( "Enable Repository", "This will create the Vela webhook for this repository." )
    in
    section [ class "settings", Util.testAttribute "repo-settings-admin" ]
        [ h2 [ class "settings-title" ] [ text "Admin" ]
        , p [ class "settings-description" ] [ text "These actions require admin privileges." ]
        , div [ class "admin-action-container" ]
            [ div [ class "admin-action-description" ]
                [ text "Chown Repository"
                , small []
                    [ em [] [ text "This will make you the owner of the webhook for this repository." ] ]
                ]
            , button
                [ class "button"
                , class "-outline"
                , attribute "aria-label" <| "become owner of the webhook for " ++ repo.full_name
                , Util.testAttribute "repo-chown"
                , onClick (chownRepoMsg { repo = repo })
                ]
                [ text "Chown" ]
            ]
        , div [ class "admin-action-container" ]
            [ div [ class "admin-action-description" ]
                [ text "Repair Repository"
                , small []
                    [ em [] [ text "This will repair the webhook for this repository." ] ]
                ]
            , button
                [ class "button"
                , class "-outline"
                , attribute "aria-label" <| "repair the webhook for " ++ repo.full_name
                , Util.testAttribute "repo-repair"
                , onClick (repairRepoMsg { repo = repo })
                ]
                [ text "Repair" ]
            ]
        , div [ class "admin-action-container" ]
            [ div [ class "admin-action-description" ]
                [ text <| Tuple.first enabledDetails
                , small [] [ em [] [ text <| Tuple.second enabledDetails ] ]
                ]
            , viewEnableButton (disableRepoMsg { repo = repo }) (enableRepoMsg { repo = repo }) repo
            ]
        ]


{-| viewEnableButton : takes enable actions and repo and returns view of the repo enable button.
-}
viewEnableButton : msg -> msg -> Vela.Repository -> Html msg
viewEnableButton disableRepoMsg enableRepoMsg repo =
    let
        baseClasses =
            classList [ ( "button", True ), ( "-outline", True ) ]

        inProgressClasses =
            classList [ ( "button", True ), ( "-outline", True ), ( "-loading", True ) ]

        baseTestAttribute =
            Util.testAttribute "repo-disable"
    in
    case repo.enabled of
        Vela.Enabled ->
            button
                [ baseClasses
                , baseTestAttribute
                , onClick disableRepoMsg
                ]
                [ text "Disable" ]

        Vela.Disabled ->
            button
                [ baseClasses
                , Util.testAttribute "repo-enable"
                , onClick enableRepoMsg
                ]
                [ text "Enable" ]

        Vela.ConfirmDisable ->
            button
                [ baseClasses
                , baseTestAttribute
                , class "-repo-disable-confirm"
                , onClick disableRepoMsg
                ]
                [ text "Confirm Disable" ]

        Vela.Disabling ->
            button
                [ inProgressClasses
                , class "button"
                , class "-outline"
                , class "-loading"
                , Util.testAttribute "repo-disabling"
                ]
                [ text "Disabling"
                , span [ class "loading-ellipsis" ] []
                ]

        Vela.Enabling ->
            div
                [ inProgressClasses
                , class "button"
                , class "-outline"
                , class "-loading"
                , Util.testAttribute "repo-enabling"
                ]
                [ text "Enabling"
                , span [ class "loading-ellipsis" ] []
                ]

        Vela.Failed ->
            button
                [ baseClasses
                , baseTestAttribute
                , disabled True
                , onClick disableRepoMsg
                ]
                [ text "Error" ]


{-| disableable : takes enabling status and returns if the repo is disableable.
-}
disableable : Vela.Enabled -> Bool
disableable status =
    case status of
        Vela.Enabled ->
            True

        Vela.ConfirmDisable ->
            True

        Vela.Disabling ->
            True

        Vela.Enabling ->
            False

        Vela.Disabled ->
            False

        Vela.Failed ->
            False


{-| viewPipelineType : takes model and repo and renders the settings category for updating repo pipeline type
-}
viewPipelineType : Vela.Repository -> (String -> msg) -> Html msg
viewPipelineType repo msg =
    section [ class "settings", Util.testAttribute "repo-settings-pipeline-type" ]
        [ h2 [ class "settings-title" ] [ text "Pipeline Type" ]
        , p [ class "settings-description" ] [ text "Change how the compiler treats the base vela config." ]
        , div [ class "form-controls", class "-stack" ]
            [ Components.Form.viewRadio
                { value = repo.pipeline_type
                , field = "yaml"
                , title = "YAML"
                , subtitle = Nothing
                , msg = msg "yaml"
                , disabled_ = False
                , id_ = "type-yaml"
                }
            , Components.Form.viewRadio
                { value = repo.pipeline_type
                , field = "go"
                , title = "Go"
                , subtitle = Nothing
                , msg = msg "go"
                , disabled_ = False
                , id_ = "type-go"
                }
            , Components.Form.viewRadio
                { value = repo.pipeline_type
                , field = "starlark"
                , title = "Starlark"
                , subtitle = Nothing
                , msg = msg "starlark"
                , disabled_ = False
                , id_ = "type-starlark"
                }
            ]
        ]
