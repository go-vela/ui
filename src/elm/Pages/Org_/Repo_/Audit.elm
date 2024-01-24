{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Audit exposing (..)

import Ansi.Log
import Api.Pagination
import Array
import Auth
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
        , small
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
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Time
import Utils.Ansi
import Utils.Errors as Errors
import Utils.Helpers as Util
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
        { org = route.params.org
        , repo = route.params.repo
        , navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    { pager : List WebLink
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { pager = []
      }
    , Effect.getRepoHooks
        { baseUrl = shared.velaAPI
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
    = GetRepoHooksResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Hook ))
    | RedeliverRepoHook { hook : Vela.Hook }
    | RedeliverRepoHookResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | GotoPage Int


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetRepoHooksResponse response ->
            Tuple.mapSecond (\_ -> Effect.sendSharedRepoHooksResponse { response = response }) <|
                case response of
                    Ok ( meta, _ ) ->
                        ( { model
                            | pager = Api.Pagination.get meta.headers
                          }
                        , Effect.none
                        )

                    Err error ->
                        ( model
                        , Effect.none
                        )

        RedeliverRepoHook options ->
            ( model
            , Effect.redeliverHook
                { baseUrl = shared.velaAPI
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
                    , Effect.addAlertSuccess { content = result, addToastIfUnique = False }
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
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetRepoHooksResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = route.params.org ++ "/" ++ route.params.repo ++ " Hooks"
    , body =
        [ viewHooks shared route.params.org route.params.repo shared.hooks
        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        ]
    }


{-| viewHooks : renders a list of hooks
-}
viewHooks : Shared.Model -> String -> String -> WebData (List Vela.Hook) -> Html Msg
viewHooks shared org repo hooks =
    let
        ( noRowsView, rows ) =
            case hooks of
                RemoteData.Success hooks_ ->
                    ( text "No hooks found for this repo"
                    , hooksToRows shared.time hooks_ org repo RedeliverRepoHook
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
                    ( Util.largeLoader, [] )

        cfg =
            Components.Table.Config
                "Hooks"
                "hooks"
                noRowsView
                tableHeaders
                rows
                Nothing
    in
    div [] [ Components.Table.view cfg ]


{-| hooksToRows : takes list of hooks and produces list of Table rows
-}
hooksToRows : Time.Posix -> List Vela.Hook -> String -> String -> ({ hook : Vela.Hook } -> Msg) -> Components.Table.Rows Vela.Hook Msg
hooksToRows now hooks org repo redeliverHook =
    hooks
        |> List.concatMap (\hook -> [ Just <| Components.Table.Row hook (renderHook now org repo redeliverHook), hookErrorRow hook ])
        |> List.filterMap identity


{-| tableHeaders : returns table headers for secrets table
-}
tableHeaders : Components.Table.Columns
tableHeaders =
    [ ( Just "-icon", "Status" )
    , ( Nothing, "source" )
    , ( Nothing, "created" )
    , ( Nothing, "host" )
    , ( Nothing, "event" )
    , ( Nothing, "branch" )
    ]


{-| renderHook : takes hook and renders a table row
-}
renderHook : Time.Posix -> String -> String -> ({ hook : Vela.Hook } -> msg) -> Vela.Hook -> Html msg
renderHook now org repo redeliverHook hook =
    tr [ Util.testAttribute <| "hooks-row", hookStatusToRowClass hook.status ]
        [ td
            [ attribute "data-label" "status"
            , class "break-word"
            , class "-icon"
            ]
            [ Components.Svgs.hookStatusToIcon hook.status ]
        , td
            [ attribute "data-label" "source-id"
            , class "no-wrap"
            ]
            [ small [] [ code [ class "source-id", class "break-word" ] [ text hook.source_id ] ] ]
        , td
            [ attribute "data-label" "created"
            , class "break-word"
            ]
            [ text <| (Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis hook.created) ]
        , td
            [ attribute "data-label" "host"
            , class "break-word"
            ]
            [ text hook.host ]
        , td
            [ attribute "data-label" "event"
            , class "break-word"
            ]
            [ text hook.event ]
        , td
            [ attribute "data-label" "branch"
            , class "break-word"
            ]
            [ text hook.branch ]
        , td
            [ attribute "data-label" ""
            , class "break-word"
            ]
            [ a
                [ href "#"
                , class "break-word"
                , Util.onClickPreventDefault <| redeliverHook { hook = hook }
                , Util.testAttribute <| "redeliver-hook-" ++ String.fromInt hook.number
                ]
                [ text "Redeliver Hook"
                ]
            ]
        ]


hookErrorRow : Vela.Hook -> Maybe (Components.Table.Row Vela.Hook msg)
hookErrorRow hook =
    if not <| String.isEmpty hook.error then
        Just <| Components.Table.Row hook renderHookError

    else
        Nothing


renderHookError : Vela.Hook -> Html msg
renderHookError hook =
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


{-| hookStatusToRowClass : takes hook status string and returns style class
-}
hookStatusToRowClass : String -> Html.Attribute msg
hookStatusToRowClass status =
    case status of
        "success" ->
            class "-success"

        "skipped" ->
            class "-skipped"

        _ ->
            class "-error"
