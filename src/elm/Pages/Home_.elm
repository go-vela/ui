{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Home_ exposing (Model, Msg, page, view)

import Auth
import Components.Crumbs
import Components.Nav
import Components.Repo
import Components.Search
    exposing
        ( toLowerContains
        , viewHomeSearchBar
        )
import Components.Svgs
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , details
        , div
        , h1
        , main_
        , p
        , summary
        , text
        )
import Html.Attributes exposing (attribute, class)
import Layouts
import List
import List.Extra
import Page exposing (Page)
import RemoteData
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Favorites as Favorites
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


{-| page : takes user, shared model, route, and returns the home page.
-}
page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user)



-- LAYOUT


{-| toLayout : takes user, model, and passes the home page info to Layouts.
-}
toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default
        { helpCommands =
            [ { name = ""
              , content = "resources on this page not yet supported via the CLI"
              , docs = Nothing
              }
            ]
        }



-- INIT


{-| Model : alias for a model object for the home page.
-}
type alias Model =
    { favoritesFilter : String
    }


{-| init : takes shared model and initializes home page input arguments.
-}
init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { favoritesFilter = ""
      }
    , Effect.getCurrentUserShared {}
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = NoOp
      -- FAVORITES
    | ToggleFavorite Vela.Org (Maybe Vela.Repo)
    | SearchFavorites String
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes current model, message, and returns an updated model and effect.
-}
update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        -- FAVORITES
        ToggleFavorite org maybeRepo ->
            ( model
            , Effect.updateFavorite { org = org, maybeRepo = maybeRepo, updateType = Favorites.Toggle }
            )

        SearchFavorites searchBy ->
            ( { model | favoritesFilter = searchBy }
            , Effect.none
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns the subscriptions for auto refreshing the page.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


{-| view : takes models, route, and creates the html for the home page.
-}
view : Shared.Model -> Route () -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Nothing ) ]
    in
    { title = "Home"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons =
                [ a
                    [ class "button"
                    , class "-outline"
                    , Util.testAttribute "source-repos"
                    , Route.Path.href Route.Path.Account_SourceRepos
                    ]
                    [ text "Source Repositories" ]
                ]
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ Util.testAttribute "overview" ] <|
                case shared.user of
                    RemoteData.Success u ->
                        if List.length u.favorites > 0 then
                            [ viewHomeSearchBar model.favoritesFilter SearchFavorites
                            , viewFavorites shared u.favorites model.favoritesFilter
                            ]

                        else
                            [ div [ class "overview" ]
                                [ h1 [] [ text "Let's get Started!" ]
                                , p [] [ text "To have Vela start building your projects we need to get them enabled." ]
                                , p []
                                    [ text "To display a repository here, click the "
                                    , Components.Svgs.star False
                                    ]
                                , p [] [ text "Enable repositories from your GitHub account on Vela now!" ]
                                , a [ class "button", Route.Path.href Route.Path.Account_SourceRepos ] [ text "Source Repositories" ]
                                ]
                            ]

                    _ ->
                        [ viewHomeSearchBar model.favoritesFilter SearchFavorites
                        , viewFavorites shared [] model.favoritesFilter
                        ]
            ]
        ]
    }


{-| viewFavorites : takes favorites, user search input and favorite action and renders favorites.
-}
viewFavorites : Shared.Model -> List String -> String -> Html Msg
viewFavorites shared favorites filter =
    if String.isEmpty filter then
        favorites
            |> toOrgFavorites
            |> viewFavoritesByOrg shared

    else
        viewFilteredFavorites shared favorites filter


{-| viewFilteredFavorites : takes favorites, user search input and favorite action and renders favorites.
-}
viewFilteredFavorites : Shared.Model -> List String -> String -> Html Msg
viewFilteredFavorites shared favorites filter =
    let
        filteredRepos =
            favorites
                |> List.filter (\repo -> toLowerContains filter repo)
    in
    div [ class "filtered-repos" ] <|
        if not <| List.isEmpty filteredRepos then
            List.map (viewFavorite shared favorites True) filteredRepos

        else
            [ div [ class "no-results" ] [ text "No results" ] ]


{-| viewFavoritesByOrg : takes favorites dictionary and favorite action and renders favorites by org.
-}
viewFavoritesByOrg : Shared.Model -> Dict String (List String) -> Html Msg
viewFavoritesByOrg shared orgFavorites =
    orgFavorites
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, favs ) -> viewOrg shared org favs)
        |> div [ class "repo-list" ]


{-| toOrgFavorites : takes favorites and organizes them by org in a dict.
-}
toOrgFavorites : List String -> Dict String (List String)
toOrgFavorites favorites =
    List.foldr
        (\x acc ->
            Dict.update
                (Maybe.withDefault "" <|
                    List.head <|
                        String.split "/" x
                )
                (Maybe.map ((::) x) >> Maybe.withDefault [ x ] >> Just)
                acc
        )
        Dict.empty
    <|
        List.sort favorites


{-| viewOrg : takes org, favorites and favorite action and renders favorites by org.
-}
viewOrg : Shared.Model -> String -> List String -> Html Msg
viewOrg shared org favorites =
    details [ class "details", class "-with-border", attribute "open" "open", Util.testAttribute "repo-org" ]
        (summary [ class "summary" ]
            [ a [ Route.Path.href <| Route.Path.Org_ { org = org } ] [ text org ]
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
            :: List.map (viewFavorite shared favorites False) favorites
        )


{-| viewFavorite : takes favorite in the form of a repo full name and renders the repo component.
-}
viewFavorite : Shared.Model -> List String -> Bool -> String -> Html Msg
viewFavorite shared favorites filtered repoFullName =
    Components.Repo.view
        shared
        { toggleFavoriteMsg = ToggleFavorite
        , org = Maybe.withDefault "" <| List.Extra.getAt 0 <| String.split "/" repoFullName
        , repo = Maybe.withDefault "" <| List.Extra.getAt 1 <| String.split "/" repoFullName
        , favorites = favorites
        , filtered = filtered
        }
