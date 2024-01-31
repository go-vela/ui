{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Settings exposing (Model, Msg, page, view)

import Auth
import Components.Form
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (Html, a, br, button, div, em, h2, h3, img, input, label, p, section, small, span, text, textarea)
import Html.Attributes exposing (alt, attribute, class, classList, disabled, for, href, id, readonly, rows, src, type_, value, wrap)
import Html.Events exposing (onClick, onInput)
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import Pages.Account.SourceRepos exposing (Msg(..))
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Time
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
    | UpdateRepoResponse { alertLabel : String } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
    | EnableRepo { repo : Vela.Repository }
    | EnableRepoResponse { repo : Vela.Repository } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
    | DisableRepo { repo : Vela.Repository }
    | DisableRepoResponse { repo : Vela.Repository } (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RepairRepo { repo : Vela.Repository }
    | RepairRepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | ChownRepo { repo : Vela.Repository }
    | ChownRepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | AllowEventsUpdate Vela.Repository String Bool
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
                    , Effect.handleHttpError { httpError = error }
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
                    , Effect.handleHttpError { httpError = error }
                    )

        UpdateRepoResponse options response ->
            case response of
                Ok ( _, repo ) ->
                    ( { model | repo = RemoteData.succeed repo }
                    , Effect.addAlertSuccess
                        { content = "Repo " ++ options.alertLabel ++ " updated."
                        , addToastIfUnique = False
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        EnableRepo options ->
            let
                payload =
                    Vela.buildEnableRepoPayload options.repo

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
                                        }
                                    )

                                _ ->
                                    ( { model
                                        | repo = RemoteData.succeed { repo | enabled = Vela.Failed }
                                      }
                                    , Effect.handleHttpError { httpError = error }
                                    )

                        _ ->
                            ( { model
                                | repo = RemoteData.succeed { repo | enabled = Vela.Failed }
                              }
                            , Effect.handleHttpError { httpError = error }
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
                        { content = result
                        , addToastIfUnique = False
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        ChownRepo options ->
            ( model
            , Effect.chownRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = ChownRepoResponse
                , org = route.params.org
                , repo = route.params.repo
                }
            )

        ChownRepoResponse response ->
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
                            { content = result
                            , addToastIfUnique = False
                            }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        RepairRepo options ->
            ( model
            , Effect.repairRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = RepairRepoResponse
                , org = route.params.org
                , repo = route.params.repo
                }
            )

        RepairRepoResponse response ->
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
                            { content = result
                            , addToastIfUnique = False
                            }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        AllowEventsUpdate repo event val ->
            let
                payload =
                    defaultRepoPayload
                        |> Vela.setAllowEvents repo event val

                body =
                    Http.jsonBody <| Vela.encodeRepoPayload payload
            in
            ( model
            , Effect.updateRepo
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateRepoResponse
                        { alertLabel = "'allowed events'"
                        }
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
                , onResponse =
                    UpdateRepoResponse
                        { alertLabel = "'visibility'"
                        }
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
                , onResponse =
                    UpdateRepoResponse
                        { alertLabel = "'build approval policy'"
                        }
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
                , onResponse =
                    UpdateRepoResponse
                        { alertLabel = "'max build limit'"
                        }
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
                , onResponse = UpdateRepoResponse { alertLabel = "'build timeout'" }
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
                , onResponse = UpdateRepoResponse { alertLabel = "'build counter'" }
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
                , onResponse = UpdateRepoResponse { alertLabel = "'pipeline type'" }
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        -- ALERTS
        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess { content = contentCopied, addToastIfUnique = False }
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
                    [ viewEvents repo
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


{-| viewEvents : takes model and repo and renders the settings category for updating repo webhook events
-}
viewEvents : Vela.Repository -> Html Msg
viewEvents repo =
    case repo.allow_events of
        Just allowEvents ->
            section [ class "settings", Util.testAttribute "repo-settings-events" ]
                [ h2 [ class "settings-title" ] [ text "Webhook Events" ]
                , p [ class "settings-description" ]
                    [ text "Control which events on Git will trigger Vela pipelines."
                    , br [] []
                    , em [] [ text "Active repositories must have at least one event enabled." ]
                    ]
                , h3 [ class "settings-subtitle" ] [ text "Push" ]
                , div [ class "form-controls", class "-two-col" ]
                    [ Components.Form.viewCheckbox
                        { title = "Push"
                        , subtitle = Nothing
                        , field = "allow_push_branch"
                        , state = allowEvents.push.branch
                        , msg = AllowEventsUpdate repo "allow_push_branch"
                        , disabled_ = False
                        }
                    , Components.Form.viewCheckbox
                        { title = "Tag"
                        , subtitle = Nothing
                        , field = "allow_push_tag"
                        , state = allowEvents.push.tag
                        , msg = AllowEventsUpdate repo "allow_push_tag"
                        , disabled_ = False
                        }
                    ]
                , h3 [ class "settings-subtitle" ] [ text "Pull Request" ]
                , div [ class "form-controls", class "-two-col" ]
                    [ Components.Form.viewCheckbox
                        { title = "Opened"
                        , subtitle = Nothing
                        , field = "allow_pull_opened"
                        , state = allowEvents.pull.opened
                        , msg = AllowEventsUpdate repo "allow_pull_opened"
                        , disabled_ = False
                        }
                    , Components.Form.viewCheckbox
                        { title = "Synchronize"
                        , subtitle = Nothing
                        , field = "allow_pull_synchronize"
                        , state = allowEvents.pull.synchronize
                        , msg = AllowEventsUpdate repo "allow_pull_synchronize"
                        , disabled_ = False
                        }
                    , Components.Form.viewCheckbox
                        { title = "Edited"
                        , subtitle = Nothing
                        , field = "allow_pull_edited"
                        , state = allowEvents.pull.edited
                        , msg = AllowEventsUpdate repo "allow_pull_edited"
                        , disabled_ = False
                        }
                    , Components.Form.viewCheckbox
                        { title = "Reopened"
                        , subtitle = Nothing
                        , field = "allow_pull_reopened"
                        , state = allowEvents.pull.reopened
                        , msg = AllowEventsUpdate repo "allow_pull_reopened"
                        , disabled_ = False
                        }
                    ]
                , h3 [ class "settings-subtitle" ] [ text "Deployments" ]
                , div [ class "form-controls", class "-two-col" ]
                    [ Components.Form.viewCheckbox
                        { title = "Created"
                        , subtitle = Nothing
                        , field = "allow_deploy_created"
                        , state = allowEvents.deploy.created
                        , msg = AllowEventsUpdate repo "allow_deploy_created"
                        , disabled_ = False
                        }
                    ]
                , h3 [ class "settings-subtitle" ] [ text "Comment" ]
                , div [ class "form-controls", class "-two-col" ]
                    [ Components.Form.viewCheckbox
                        { title = "Created"
                        , subtitle = Nothing
                        , field = "allow_comment_created"
                        , state = allowEvents.comment.created
                        , msg = AllowEventsUpdate repo "allow_comment_created"
                        , disabled_ = False
                        }
                    , Components.Form.viewCheckbox
                        { title = "Edited"
                        , subtitle = Nothing
                        , field = "allow_comment_edited"
                        , state = allowEvents.comment.edited
                        , msg = AllowEventsUpdate repo "allow_comment_edited"
                        , disabled_ = False
                        }
                    ]
                ]

        Nothing ->
            text ""


{-| viewAccess : takes model and repo and renders the settings category for updating repo access
-}
viewAccess : Vela.Repository -> (String -> msg) -> Html msg
viewAccess repo msg =
    section [ class "settings", Util.testAttribute "repo-settings-access" ]
        [ h2 [ class "settings-title" ] [ text "Access" ]
        , p [ class "settings-description" ] [ text "Change who can access build information." ]
        , div [ class "form-controls", class "-stack" ]
            [ Components.Form.viewRadio
                { title = "Private"
                , subtitle = Just (text "(anyone with access to this Vela instance)")
                , value = repo.visibility
                , field = "private"
                , msg = msg "private"
                , disabled_ = False
                }
            , Components.Form.viewRadio
                { title = "Any"
                , subtitle = Just (text "(anyone with access to this Vela instance)")
                , value = repo.visibility
                , field = "public"
                , msg = msg "public"
                , disabled_ = False
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
                }
            , Components.Form.viewRadio
                { title = "Require Admin Approval When Contributor Is Read Only"
                , subtitle = Just (text "(repository admin must approve all builds from outside contributors with read-only access to the repo)")
                , value = repo.approve_build
                , field = "fork-no-write"
                , msg = msg "fork-no-write"
                , disabled_ = False
                }
            , Components.Form.viewRadio
                { title = "Never Require Admin Approval"
                , subtitle = Just (text "(any outside contributor can run a PR build)")
                , value = repo.approve_build
                , field = "never"
                , msg = msg "never"
                , disabled_ = False
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
    button
        [ classList
            [ ( "button", True )
            , ( "-outline", True )
            ]
        , onClick msg
        , disabled <| not <| validLimit shared.velaMaxBuildLimit inLimit repo <| Just repo.limit
        ]
        [ text "update" ]


{-| viewLimitWarning : takes maybe string of user entered limit and renders a disclaimer on updating the build limit.
-}
viewLimitWarning : Int -> Maybe Int -> Html msg
viewLimitWarning maxLimit inLimit =
    p [ class "notice" ]
        [ text "Disclaimer: it is highly recommended to optimize your pipeline before increasing this value. Limits must also lie between 1 and "
        , text <| String.fromInt maxLimit
        , text "."
        ]


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
            , button
                [ classList
                    [ ( "button", True )
                    , ( "-outline", True )
                    ]
                , onClick <| clickMsg <| Maybe.withDefault 0 inTimeout
                , disabled <| not <| validTimeout inTimeout <| Just repo.timeout
                ]
                [ text "update" ]
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
    button
        [ classList
            [ ( "button", True )
            , ( "-outline", True )
            ]
        , onClick msg
        , disabled <| not <| validCounter inCounter repo <| Just repoCounter
        ]
        [ text "update" ]


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
                , class "repo-disable-confirm"
                , onClick disableRepoMsg
                , class "-secret-delete-confirm"
                ]
                [ text "Really Disable?" ]

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
                }
            , Components.Form.viewRadio
                { value = repo.pipeline_type
                , field = "go"
                , title = "Go"
                , subtitle = Nothing
                , msg = msg "go"
                , disabled_ = False
                }
            , Components.Form.viewRadio
                { value = repo.pipeline_type
                , field = "starlark"
                , title = "Starlark"
                , subtitle = Nothing
                , msg = msg "starlark"
                , disabled_ = False
                }
            ]
        ]
