{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Reports exposing (..)

import Auth
import Effect exposing (Effect)
import Html exposing (a, button, div, li, text, ul)
import Html.Attributes exposing (class, href)
import Html.Events
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Utils.Errors as Errors
import Vela
import View exposing (View)


{-| page : takes user, shared model, route, and returns a build's reports page.
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



-- LAYOUT


{-| toLayout : takes user, route, model, and passes a build's pipeline page info to Layouts.
-}
toLayout : Auth.User -> Route { org : String, repo : String, build : String } -> Model -> Layouts.Layout Msg
toLayout _ route _ =
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
                Route.Path.Org__Repo__Build__Reports
                    { org = route.params.org
                    , repo = route.params.repo
                    , build = build
                    }
        }



-- INIT


type alias Model =
    { build : WebData Vela.Build
    , attachments : WebData (List Vela.TestAttachment)
    , activeTab : String
    }


init : Shared.Model -> Route { org : String, repo : String, build : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { build = RemoteData.Loading
      , attachments = RemoteData.Loading
      , activeTab = "attachments"
      }
    , Effect.getBuildTestAttachments
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetAttachmentsResponse
        , org = route.params.org
        , repo = route.params.repo
        , build = route.params.build
        }
    )



-- UPDATE


type Msg
    = NoOp
    | DownloadTextAttachment { filename : String, content : String, map : String -> String }
    | GetAttachmentsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.TestAttachment ))
    | SelectTab String


{-| update : takes current models, route, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { org : String, repo : String, build : String } -> Msg -> Model -> ( Model, Effect Msg )
update _ _ msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        DownloadTextAttachment options ->
            ( model
            , Effect.downloadFile options
            )

        GetAttachmentsResponse response ->
            case response of
                Ok ( _, attachments ) ->
                    ( { model | attachments = RemoteData.Success attachments }
                    , Effect.none
                    )

                Err error ->
                    ( { model | attachments = Errors.toFailure error }
                    , Effect.none
                    )

        SelectTab tab ->
            ( { model | activeTab = tab }
            , Effect.none
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, build : String } -> Model -> View Msg
view _ _ model =
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

        downloadLinks =
            case model.attachments of
                RemoteData.Success attachments ->
                    div [ class "attachments-list" ]
                        (List.map viewAttachment (List.sortBy .file_name attachments))

                RemoteData.Loading ->
                    div [ class "report-output" ] [ text "Loading attachments..." ]

                RemoteData.Failure error ->
                    div [ class "report-output" ]
                        [ text ("Failed to load attachments: " ++ httpErrorToString error) ]

                RemoteData.NotAsked ->
                    div [ class "report-output" ] [ text "No attachments requested" ]

        viewAttachment attachment =
            a
                [ class "report-output attachment-link"
                , href attachment.presigned_url
                ]
                [ text attachment.file_name ]
    in
    { title = "Reports"
    , body =
        [ div [ class "reports-layout" ]
            [ div [ class "reports-buttons-section" ]
                [ ul [ class "reports-buttons" ]
                    [ li []
                        [ button
                            [ class <|
                                "reports-button"
                                    ++ (if model.activeTab == "attachments" then
                                            " active"

                                        else
                                            ""
                                       )
                            , Html.Events.onClick (SelectTab "attachments")
                            ]
                            [ text "Attachments" ]
                        ]

                    -- , li []
                    --     [ button
                    --         [ class "reports-button"
                    --         ]
                    --         [ text "test results" ]
                    --     ]
                    ]
                ]
            , div [ class "reports-downloads-section" ]
                [ downloadLinks
                ]
            ]
        ]
    }
