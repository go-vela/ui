{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Pager exposing (defaultLabels, prevNextLabels, view, viewIfNeeded)

import Api.Pagination as Pagination
import FeatherIcons
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (attribute, class, disabled)
import Html.Events exposing (onClick)
import LinkHeader exposing (WebLink)
import RemoteData exposing (WebData)
import Utils.Helpers as Util


type alias Labels =
    { previousLabel : String
    , nextLabel : String
    }


defaultLabels : Labels
defaultLabels =
    { previousLabel = "newer"
    , nextLabel = "older"
    }


prevNextLabels : Labels
prevNextLabels =
    { previousLabel = "prev"
    , nextLabel = "next"
    }


{-| view : renders pager controls
-}
view : List WebLink -> Labels -> (Pagination.Page -> msg) -> Html msg
view links labels toMsg =
    let
        linkRels : List LinkHeader.LinkRel
        linkRels =
            List.map .rel links

        -- note: list is empty if there's only one page
        isFirst : Bool
        isFirst =
            List.member (LinkHeader.RelNext 2) linkRels

        maybePrevPage : Maybe LinkHeader.LinkRel
        maybePrevPage =
            linkRels
                |> List.filter
                    (\link ->
                        case link of
                            LinkHeader.RelPrev _ ->
                                True

                            _ ->
                                False
                    )
                |> List.head

        maybeNextPage : Maybe LinkHeader.LinkRel
        maybeNextPage =
            linkRels
                |> List.filter
                    (\link ->
                        case link of
                            LinkHeader.RelNext _ ->
                                True

                            _ ->
                                False
                    )
                |> List.head

        isLast : Bool
        isLast =
            case ( maybePrevPage, maybeNextPage ) of
                ( Just (LinkHeader.RelPrev _), Nothing ) ->
                    True

                _ ->
                    False

        nextPage : Int
        nextPage =
            case maybeNextPage of
                Just (LinkHeader.RelNext num) ->
                    num

                _ ->
                    1

        prevPage : Int
        prevPage =
            case maybePrevPage of
                Just (LinkHeader.RelPrev num) ->
                    num

                _ ->
                    1
    in
    div [ class "pager-actions" ]
        [ button
            [ disabled <| isFirst || (List.length links == 0)
            , Util.testAttribute "pager-previous"
            , class "button"
            , class "-outline"
            , class "pager-icon-prev"
            , onClick (toMsg prevPage)
            ]
            [ FeatherIcons.chevronLeft
                |> FeatherIcons.withSize 18
                |> FeatherIcons.toHtml [ attribute "aria-hidden" "true" ]
            , text labels.previousLabel
            ]
        , button
            [ disabled <| isLast || (List.length links == 0)
            , Util.testAttribute "pager-next"
            , class "button"
            , class "-outline"
            , class "pager-icon-next"
            , onClick (toMsg nextPage)
            ]
            [ text labels.nextLabel
            , FeatherIcons.chevronRight
                |> FeatherIcons.withSize 18
                |> FeatherIcons.toHtml [ attribute "aria-hidden" "true" ]
            ]
        ]


viewIfNeeded : List WebLink -> Labels -> (Pagination.Page -> msg) -> WebData (List a) -> Html msg
viewIfNeeded links labels gotoPageMsg resources =
    RemoteData.unwrap (text "")
        (\builds ->
            if List.length builds > 0 then
                view links labels gotoPageMsg

            else
                text ""
        )
        resources
