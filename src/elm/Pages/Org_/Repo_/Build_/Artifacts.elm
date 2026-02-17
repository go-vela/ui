{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Artifacts exposing (..)

import Auth
import Components.Table
import Effect exposing (Effect)
import Html exposing (a, div, text, tr)
import Html.Attributes exposing (class, href, rel, target)
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors as Errors
import Utils.Interval as Interval
import Vela
import View exposing (View)


{-| page : takes user, shared model, route, and returns a build's artifacts page.
-}
page : Auth.User -> Shared.Model -> Route { org : String, repo : String, build : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)
        |> Page.withOnQueryParameterChanged
            { key = "tab_switch"
            , onChange = TabSwitched
            }



-- LAYOUT


{-| toLayout : takes user, route, model, and passes a build's artifacts page info to Layouts.
-}
toLayout : Auth.User -> Route { org : String, repo : String, build : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Build
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "View Build"
              , content =
                    "vela view build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/view"
              }
            , { name = "Approve Build"
              , content =
                    "vela approve build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/approve"
              }
            , { name = "Restart Build"
              , content =
                    "vela restart build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/restart"
              }
            , { name = "Cancel Build"
              , content =
                    "vela cancel build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/cancel"
              }
            ]
        , crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Just <| Route.Path.Org__Repo_ { org = route.params.org, repo = route.params.repo } )
            , ( "#" ++ route.params.build, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        , build = route.params.build
        , toBuildPath =
            \build ->
                Route.Path.Org__Repo__Build__Artifacts
                    { org = route.params.org
                    , repo = route.params.repo
                    , build = build
                    }
        }



-- INIT


type alias Model =
    { build : WebData Vela.Build
    , artifacts : WebData (List Vela.ArtifactObject)
    , buildCompleted : Bool
    }


{-| init : takes shared model, route, and unit, and returns a model and effect.
-}
init : Shared.Model -> Route { org : String, repo : String, build : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { build = RemoteData.Loading
      , artifacts = RemoteData.Loading
      , buildCompleted = False
      }
    , Effect.batch
        [ Effect.getBuild
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetBuildResponse
            , org = route.params.org
            , repo = route.params.repo
            , build = route.params.build
            }
        , fetchArtifacts shared route
        ]
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = NoOp
    | DownloadTextArtifact { filename : String, content : String, map : String -> String }
    | GetBuildResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
    | GetArtifactsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.ArtifactObject ))
    | TabSwitched { from : Maybe String, to : Maybe String }
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes current models, route info, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { org : String, repo : String, build : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        DownloadTextArtifact options ->
            ( model
            , Effect.downloadFile options
            )

        GetBuildResponse response ->
            case response of
                Ok ( _, build ) ->
                    let
                        completed =
                            build.finished /= 0

                        shouldRefreshArtifacts =
                            completed && not model.buildCompleted
                    in
                    ( { model
                        | build = RemoteData.Success build
                        , buildCompleted = completed
                      }
                    , if shouldRefreshArtifacts then
                        fetchArtifacts shared route

                      else
                        Effect.none
                    )

                Err error ->
                    ( { model | build = Errors.toFailure error }
                    , Effect.none
                    )

        GetArtifactsResponse response ->
            case response of
                Ok ( _, artifacts ) ->
                    ( { model | artifacts = RemoteData.Success artifacts }
                    , Effect.none
                    )

                Err error ->
                    ( { model | artifacts = Errors.toFailure error }
                    , Effect.none
                    )

        TabSwitched options ->
            if options.to == Just "true" then
                ( { model | artifacts = RemoteData.Loading }
                , fetchArtifacts shared route
                )

            else
                ( model
                , Effect.none
                )

        Tick _ ->
            if buildIsComplete model then
                ( model
                , Effect.none
                )

            else
                ( model
                , Effect.getBuild
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetBuildResponse
                    , org = route.params.org
                    , repo = route.params.repo
                    , build = route.params.build
                    }
                )


{-| subscriptions : takes model and returns that there are no subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    if buildIsComplete model then
        Sub.none

    else
        Interval.tickEveryFiveSeconds Tick



-- VIEW


{-| view : takes models, route, and creates the html for a build's artifacts page.
-}
view : Shared.Model -> Route { org : String, repo : String, build : String } -> Model -> View Msg
view shared _ model =
    let
        httpErrorToString error =
            case error of
                Http.BadUrl url ->
                    "Bad URL: " ++ url

                Http.Timeout ->
                    "Network timeout"

                Http.NetworkError ->
                    "Network error"

                Http.BadStatus statusCode ->
                    "HTTP " ++ String.fromInt statusCode

                Http.BadBody body ->
                    "Bad response: " ++ body

        noRowsView =
            text "No artifacts found for this build."

        artifactsTable =
            case model.artifacts of
                RemoteData.Success artifacts ->
                    Components.Table.view
                        (Components.Table.Config
                            "Artifacts"
                            "build-artifacts"
                            noRowsView
                            tableHeaders
                            (artifactsToRows (List.sortBy (\artifact -> objectKeyToFileName artifact.name) artifacts))
                            Nothing
                            1
                        )

                RemoteData.Loading ->
                    div [ class "artifact-output" ] [ text "Loading artifacts..." ]

                RemoteData.Failure error ->
                    div [ class "artifact-output" ]
                        [ text ("Failed to load artifacts: " ++ httpErrorToString error) ]

                RemoteData.NotAsked ->
                    div [ class "artifact-output" ] [ text "No artifacts requested" ]
    in
    { title = "Artifacts"
    , body =
        [ div [ class "artifacts-layout" ]
            [ artifactsTable
            ]
        ]
    }


{-| artifactsToRows : takes list of artifacts and produces list of Table rows.
-}
artifactsToRows : List Vela.ArtifactObject -> Components.Table.Rows Vela.ArtifactObject Msg
artifactsToRows artifacts =
    artifacts
        |> List.map (\artifact -> Components.Table.Row artifact viewArtifact)


buildIsComplete : Model -> Bool
buildIsComplete model =
    case model.build of
        RemoteData.Success build ->
            build.finished /= 0

        _ ->
            False


fetchArtifacts : Shared.Model -> Route { org : String, repo : String, build : String } -> Effect Msg
fetchArtifacts shared route =
    Effect.getBuildArtifacts
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetArtifactsResponse
        , bucket = shared.velaStorageBucket
        , org = route.params.org
        , repo = route.params.repo
        , build = route.params.build
        }


{-| tableHeaders : returns table headers for artifacts table.
-}
tableHeaders : Components.Table.Columns
tableHeaders =
    [ ( Just "name", "name" )
    ]


{-| viewArtifact : takes an artifact and renders a table row.
-}
viewArtifact : Vela.ArtifactObject -> Html.Html Msg
viewArtifact artifact =
    let
        fileName =
            objectKeyToFileName artifact.name

        artifactContent =
            case artifact.url of
                Just url ->
                    a
                        [ href url
                        , target "_blank"
                        , rel "noopener noreferrer"
                        ]
                        [ text fileName ]

                Nothing ->
                    text fileName
    in
    tr []
        [ Components.Table.viewItemCell
            { dataLabel = "name"
            , parentClassList = [ ( "name", True ) ]
            , itemClassList = [ ( "-block", True ) ]
            , children = [ artifactContent ]
            }
        ]


objectKeyToFileName : String -> String
objectKeyToFileName objectKey =
    objectKey
        |> String.split "/"
        |> List.reverse
        |> List.head
        |> Maybe.withDefault objectKey
