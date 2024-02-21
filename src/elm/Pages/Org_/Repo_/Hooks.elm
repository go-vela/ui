{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Hooks exposing (..)

import Ansi.Log
import Api.Pagination
import Array
import Auth
import Components.Loading
import Components.Pager
import Components.Svgs
import Components.Table
import Dict
import Effect exposing (Effect)
import Html
    exposing
        ( Html
        , a
        , code
        , div
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
        , rows
        )
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import List
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Ansi
import Utils.Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
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
            [ { name = "Validate Pipeline Help"
              , content = "vela validate pipeline -h"
              , docs = Just "cli/pipeline/validate"
              }
            , { name = "List Hooks"
              , content =
                    "vela get hooks --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
              , docs = Just "hook/get"
              }
            , { name = "View Hook"
              , content =
                    "vela view hook --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --hook 1"
              , docs = Just "hook/view"
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
    { hooks : WebData (List Vela.Hook)
    , pager : List WebLink
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { hooks = shared.hooks
      , pager = []
      }
    , Effect.getRepoHooks
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetRepoHooksResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = -- HOOKS
      GetRepoHooksResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Hook ))
    | RedeliverRepoHook { hook : Vela.Hook }
    | RedeliverRepoHookResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | GotoPage Int
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- HOOKS
        GetRepoHooksResponse response ->
            case response of
                Ok ( meta, hooks ) ->
                    ( { model
                        | hooks = RemoteData.succeed hooks
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | hooks = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        RedeliverRepoHook options ->
            ( model
            , Effect.redeliverHook
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = RedeliverRepoHookResponse
                , org = route.params.org
                , repo = route.params.repo
                , hookNumber = String.fromInt <| options.hook.number
                }
            )

        RedeliverRepoHookResponse response ->
            case response of
                Ok ( _, result ) ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = result
                        , addToastIfUnique = False
                        , link = Nothing
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        GotoPage pageNumber ->
            ( model
            , Effect.batch
                [ Effect.replaceRoute
                    { path = route.path
                    , query =
                        Dict.update "page" (\_ -> Just <| String.fromInt pageNumber) route.query
                    , hash = route.hash
                    }
                , Effect.getRepoHooks
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetRepoHooksResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getRepoHooks
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetRepoHooksResponse
                , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
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
    { title = "Audit" ++ Util.pageToString (Dict.get "page" route.query)
    , body =
        [ viewHooks shared model model.hooks
        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        ]
    }


{-| viewHooks : renders a list of hooks
-}
viewHooks : Shared.Model -> Model -> WebData (List Vela.Hook) -> Html Msg
viewHooks shared model hooks =
    let
        actions =
            Just <|
                Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage

        ( noRowsView, rows ) =
            case hooks of
                RemoteData.Success hooks_ ->
                    ( text "No hooks found for this repo"
                    , hooksToRows shared.time hooks_ RedeliverRepoHook
                    )

                RemoteData.Failure error ->
                    ( span [ Util.testAttribute "hooks-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No hooks found for this repo, most likely due to not having sufficient permissions to the source control repo"

                                        _ ->
                                            "No hooks found for this repo, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No hooks found for this repo, there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( Components.Loading.viewSmallLoader, [] )

        cfg =
            Components.Table.Config
                "Hooks"
                "hooks"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div [] [ Components.Table.view cfg ]


{-| hooksToRows : takes list of hooks and produces list of Table rows
-}
hooksToRows : Time.Posix -> List Vela.Hook -> ({ hook : Vela.Hook } -> Msg) -> Components.Table.Rows Vela.Hook Msg
hooksToRows now hooks redeliverHook =
    hooks
        |> List.concatMap (\hook -> [ Just <| Components.Table.Row hook (viewHook now redeliverHook), hookErrorRow hook ])
        |> List.filterMap identity


{-| tableHeaders : returns table headers for secrets table
-}
tableHeaders : Components.Table.Columns
tableHeaders =
    [ ( Just "table-icon", "status" )
    , ( Nothing, "source" )
    , ( Nothing, "created" )
    , ( Nothing, "host" )
    , ( Nothing, "event" )
    , ( Nothing, "branch" )
    ]


{-| viewHook : takes hook and renders a table row
-}
viewHook : Time.Posix -> ({ hook : Vela.Hook } -> msg) -> Vela.Hook -> Html msg
viewHook now redeliverHook hook =
    tr [ Util.testAttribute <| "hooks-row", hookStatusToRowClass hook.status ]
        [ Components.Table.viewIconCell
            { dataLabel = "status"
            , parentClassList = []
            , itemWrapperClassList = []
            , itemClassList = []
            , children =
                [ Components.Svgs.hookStatusToIcon hook.status
                ]
            }
        , Components.Table.viewListItemCell
            { dataLabel = "source-id"
            , parentClassList = []
            , itemWrapperClassList = [ ( "source-id", True ) ]
            , itemClassList = []
            , children =
                [ text hook.source_id
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "created"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| (Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis hook.created)
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "host"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| hook.host
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "event"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| hook.event
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "branch"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| hook.branch
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = ""
            , parentClassList = []
            , itemClassList = []
            , children =
                [ a
                    [ href "#"
                    , class "break-word"
                    , Util.onClickPreventDefault <| redeliverHook { hook = hook }
                    , Util.testAttribute <| "redeliver-hook-" ++ String.fromInt hook.number
                    ]
                    [ text "Redeliver Hook"
                    ]
                ]
            }
        ]


hookErrorRow : Vela.Hook -> Maybe (Components.Table.Row Vela.Hook msg)
hookErrorRow hook =
    if not <| String.isEmpty hook.error then
        Just <| Components.Table.Row hook viewHookError

    else
        Nothing


viewHookError : Vela.Hook -> Html msg
viewHookError hook =
    let
        lines =
            Utils.Ansi.decodeAnsi hook.error
                |> Array.map
                    (\line ->
                        Just <|
                            Ansi.Log.viewLine line
                    )
                |> Array.toList
                |> List.filterMap identity

        msgRow =
            case hook.status of
                "skipped" ->
                    tr [ class "skipped-data", Util.testAttribute "hooks-skipped" ]
                        [ td [ attribute "colspan" "6" ]
                            [ code [ class "skipped-content" ]
                                lines
                            ]
                        ]

                _ ->
                    tr [ class "error-data", Util.testAttribute "hooks-error" ]
                        [ td [ attribute "colspan" "6" ]
                            [ code [ class "error-content" ]
                                lines
                            ]
                        ]
    in
    msgRow


hookStatusToRowClass : String -> Html.Attribute msg
hookStatusToRowClass status =
    case status of
        "success" ->
            class "-success"

        "skipped" ->
            class "-skipped"

        _ ->
            class "-error"
