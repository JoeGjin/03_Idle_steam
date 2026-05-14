extends Control



@onready var collection_book: Control = %CollectionBook
@onready var postcard_showing: Control = %PostcardShowing








func play_receive_postcard():
    collection_book.hide()
    postcard_showing.show()
    postcard_showing.show_postcard()



func _ready():
    collection_book.show()
    postcard_showing.hide()


func _on_postcard_showing_postcard_showed() -> void:
    postcard_showing.hide()
    collection_book.show()
