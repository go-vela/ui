module Pages.Home_ exposing (Model, Msg, page, view)

import Auth
import Dict exposing (Dict)
import Effect exposing (Effect)
import Favorites exposing (ToggleFavorite, starToggle)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , details
        , div
        , h1
        , p
        , span
        , summary
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        )
import List
import List.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Routes
import Search
    exposing
        ( homeSearchBar
        , toLowerContains
        )
import Shared
import SvgBuilder
import Util
import Vela exposing (Favorites, Org, Repo)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update
        , subscriptions = subscriptions
        , view = view shared
        }



-- INIT


type alias Model =
    { favoritesFilter : String
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { favoritesFilter = ""
      }
    , Effect.getCurrentUser {}
    )



-- UPDATE


type Msg
    = NoOp
    | ToggleFavorite Org (Maybe Repo)
    | SearchFavorites String


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        SearchFavorites searchBy ->
            ( { model | favoritesFilter = searchBy }
            , Effect.none
            )

        ToggleFavorite org maybeRepo ->
            ( model
            , Effect.toggleFavorites { org = org, maybeRepo = maybeRepo }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes current user, user input and action params and renders home page with favorited repos
-}
view : Shared.Model -> Model -> View Msg
view shared model =
    let
        blankMessage : Html msg
        blankMessage =
            div [ class "overview" ]
                [ h1 [] [ text "Let's get Started!" ]
                , p [] [ text "To have Vela start building your projects we need to get them enabled." ]
                , p []
                    [ text "To display a repository here, click the "
                    , SvgBuilder.star False
                    ]
                , p [] [ text "Enable repositories from your GitHub account on Vela now!" ]
                , a [ class "button", Routes.href Routes.SourceRepositories ] [ text "Source Repositories" ]
                ]

        body =
            div [ Util.testAttribute "overview" ] <|
                case shared.user of
                    Success u ->
                        if List.length u.favorites > 0 then
                            [ homeSearchBar model.favoritesFilter SearchFavorites
                            , viewFavorites u.favorites model.favoritesFilter
                            ]

                        else
                            [ blankMessage ]

                    Loading ->
                        [ h1 [] [ Util.largeLoader ] ]

                    NotAsked ->
                        [ homeSearchBar model.favoritesFilter SearchFavorites
                        , viewFavorites [] model.favoritesFilter
                        ]

                    -- [ text "not asked" ]
                    Failure _ ->
                        [ text "failed" ]
    in
    { title = "Pages.Home_New_"
    , body =
        [ body
        ]
    }


{-| viewFavorites : takes favorites, user search input and favorite action and renders favorites
-}
viewFavorites : Favorites -> String -> Html Msg
viewFavorites favorites filter =
    if String.isEmpty filter then
        favorites
            |> toOrgFavorites
            |> viewFavoritesByOrg

    else
        viewFilteredFavorites favorites filter


{-| viewFilteredFavorites : takes favorites, user search input and favorite action and renders favorites
-}
viewFilteredFavorites : Favorites -> String -> Html Msg
viewFilteredFavorites favorites filter =
    let
        filteredRepos =
            favorites
                |> List.filter (\repo -> toLowerContains filter repo)
    in
    div [ class "filtered-repos" ] <|
        if not <| List.isEmpty filteredRepos then
            filteredRepos
                |> List.map (viewFavorite favorites True)

        else
            [ div [ class "no-results" ] [ text "No results" ] ]


{-| viewFavoritesByOrg : takes favorites dictionary and favorite action and renders favorites by org
-}
viewFavoritesByOrg : Dict String Favorites -> Html Msg
viewFavoritesByOrg orgFavorites =
    orgFavorites
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, favs ) -> viewOrg org favs)
        |> div [ class "repo-list" ]


{-| toOrgFavorites : takes favorites and organizes them by org in a dict
-}
toOrgFavorites : Favorites -> Dict String Favorites
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


{-| viewOrg : takes org, favorites and favorite action and renders favorites by org
-}
viewOrg : String -> Favorites -> Html Msg
viewOrg org favorites =
    details [ class "details", class "-with-border", attribute "open" "open", Util.testAttribute "repo-org" ]
        (summary [ class "summary" ]
            [ a [ Routes.href <| Routes.OrgRepositories org Nothing Nothing ] [ text org ]
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
            :: List.map (viewFavorite favorites False) favorites
        )


{-| viewFavorite : takes favorites and favorite action and renders single favorite
-}
viewFavorite : Favorites -> Bool -> String -> Html Msg
viewFavorite favorites filtered favorite =
    let
        ( org, repo ) =
            ( Maybe.withDefault "" <| List.Extra.getAt 0 <| String.split "/" favorite
            , Maybe.withDefault "" <| List.Extra.getAt 1 <| String.split "/" favorite
            )

        name =
            if filtered then
                favorite

            else
                repo
    in
    div [ class "item", Util.testAttribute "repo-item" ]
        [ div [] [ text name ]
        , div [ class "buttons" ]
            [ starToggle org repo ToggleFavorite <| List.member favorite favorites
            , a
                [ class "button"
                , class "-outline"
                , Routes.href <| Routes.RepoSettings org repo
                ]
                [ text "Settings" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-hooks"
                , Routes.href <| Routes.Hooks org repo Nothing Nothing
                ]
                [ text "Hooks" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-secrets"
                , Routes.href <| Routes.RepoSecrets "native" org repo Nothing Nothing
                ]
                [ text "Secrets" ]
            , a
                [ class "button"
                , Util.testAttribute "repo-view"
                , Routes.href <| Routes.RepositoryBuilds org repo Nothing Nothing Nothing
                ]
                [ text "View" ]
            ]
        ]
