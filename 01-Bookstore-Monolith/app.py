from flask import Flask, render_template, jsonify, request
from pymongo import MongoClient
from bson.objectid import ObjectId
from google import genai  # The modern unified Google Gen AI SDK
import os

app = Flask(__name__)

# Look for an environment variable called 'MONGO_URI'. 
# If it doesn't exist, fall back to the Docker network name.
MONGO_URI = os.getenv("MONGO_URI", "mongodb://mongodb-backend:27017/bookstore")

client = MongoClient(MONGO_URI)
db = client['bookstore'] # Access your bookstore database

# 1. Pull the key directly from the environment variables injected by Docker Compose
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# 2. Add an upfront validation gate. If the key is missing, crash the server immediately 
# on startup so you don't run into confusing 500 errors deep inside your routes later.
if not GEMINI_API_KEY:
    raise ValueError("CRITICAL INITIALIZATION ERROR: GEMINI_API_KEY environment variable is completely missing!")

# 3. Initialize the GenAI Client using the verified environment token
ai_client = genai.Client(api_key=GEMINI_API_KEY)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/books', methods=['GET'])
def add_book():
    try:
        books_cursor = db['books'].find()
        books_list = []
        for book in books_cursor:
            book['_id'] = str(book['_id'])
            books_list.append(book)
        return jsonify(books_list)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/books/<string:book_id>', methods=['GET'])
def get_book(book_id):
    try:
        book = db['books'].find_one({'_id': ObjectId(book_id)})
        if book:
            book['_id'] = str(book['_id'])
            return render_template('book-detail.html', book=book)
        else:
            return jsonify({"error": "Book not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ============================================================================================
# Free Tier Gemini Summary Endpoint
# ============================================================================================
@app.route('/api/books/<string:book_id>/summary', methods=['GET'])
def get_book_summary(book_id):
    try:
        # 1. Look up book details from the local MongoDB workspace
        book = db['books'].find_one({'_id': ObjectId(book_id)})
        if not book:
            return jsonify({"error": "Target book record missing from database"}), 404
        
        title = book.get("title", "Unknown Context")
        author = book.get("author", "Unknown Creator")
        category = book.get("category", "General Fiction")
        
        # 2. Frame the query prompt execution parameters
        prompt = f"""
        You are an elite, insightful literary review assistant for an online bookstore application.
        Analyze the following details and provide a high-level concise summary, 
        literary tone assessment, and 3 key thematic insights for target readers.
        
        Book Title: {title}
        Author: {author}
        Genre Classification: {category}
        
        Ensure your layout is well-organized with clear bold structural sections. Do not use generic filler words.
        """
        
        # 3. Call the ultra-fast, free tier gemini-2.5-flash model
        response = ai_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )
        
        return jsonify({
            "book_id": book_id,
            "ai_summary": response.text
        }), 200

    except Exception as e:
        return jsonify({"error": f"Internal pipeline execution error: {str(e)}"}), 500

# ============================================================================================

@app.route('/category/<string:category_name>', methods=['GET'])
def show_category_page(category_name):
    return render_template('category.html', category_name=category_name)

@app.route('/api/books/category/<string:category_name>', methods=['GET'])
def get_books_by_category(category_name):
    try:
        books_collection = db['books']
        books_cursor = books_collection.find({"category": category_name})
        books_list = []
        for book in books_cursor:
            book['_id'] = str(book['_id']) 
            books_list.append(book)
        return jsonify(books_list)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

# ============================================================================================
# Basic Version -1

# import os
# from flask import Flask, render_template, jsonify, request
# from pymongo import MongoClient
# from bson.objectid import ObjectId

# app = Flask(__name__)

# # mongo_uri = "mongodb://localhost:27017"

# # to run this follow this step:
# # first run this in terminal ->  .\env\Scripts\activate
# # then after that run this ->  python app.py

# # Configure MongoDB client
# mongo_uri = os.environ.get("MONGO_URI", "mongodb://localhost:27017") # to use in k8s

# client = MongoClient(mongo_uri)
# db = client['bookstore']  # Replace with your database name

# @app.route('/')
# def index():
#     return render_template('index.html')

# # Example API route to add a new book
# @app.route('/books', methods=['GET'])
# def add_book():
#     try:
#         # Fetch all books from the 'books' collection
#         books_cursor = db['books'].find()
#         books_list = []
        
#         for book in books_cursor:
#             # Convert ObjectId to string
#             book['_id'] = str(book['_id'])
#             # Append book data to list
#             books_list.append(book)
        
#         return jsonify(books_list)
#     except Exception as e:
#         return jsonify({"error": str(e)}), 500

# # Route to fetch a single book by ID and render details page
# @app.route('/books/<string:book_id>', methods=['GET'])
# def get_book(book_id):
#     try:
#         book = db['books'].find_one({'_id': ObjectId(book_id)})
#         if book:
#             # Convert ObjectId to string
#             book['_id'] = str(book['_id'])
#             return render_template('book-detail.html', book=book)
#         else:
#             return jsonify({"error": "Book not found"}), 404
#     except Exception as e:
#         return jsonify({"error": str(e)}), 500


# # Create a Flask route to retrieve all categories from the database.
# # @app.route('/category', methods=['GET'])
# # def get_categories():
# #     try:
# #         categories_collection = db['categories']
# #         categories_cursor = categories_collection.find()
# #         categories_list = []
        
# #         for category in categories_cursor:
# #             category['_id'] = str(category['_id'])  # Convert ObjectId to string
# #             categories_list.append(category)
        
# #         return jsonify(categories_list)
# #     except Exception as e:
# #         return jsonify({"error": str(e)}), 500


# # Route to display category.html page
# @app.route('/category/<string:category_name>', methods=['GET'])
# def show_category_page(category_name):
#     return render_template('category.html', category_name=category_name)


# # To display books in category html page
# @app.route('/api/books/category/<string:category_name>', methods=['GET'])
# def get_books_by_category(category_name):
#     try:
#         books_collection = db['books']
#         books_cursor = books_collection.find({"category": category_name})
#         books_list = []
        
#         for book in books_cursor:
#             book['_id'] = str(book['_id'])  # Convert ObjectId to string
#             books_list.append(book)
        
#         return jsonify(books_list)
#     except Exception as e:
#         return jsonify({"error": str(e)}), 500




# if __name__ == "__main__":
#     app.run(host="0.0.0.0", port=5000, debug=True)

# ============================================================================================

# Example API route to retrieve a single book by ID
# @app.route('/books/<string:book_id>', methods=['GET'])
# def get_book(book_id):
#     try:
#         # Fetch a single book from the 'books' collection
#         book = db['books'].find_one({'_id': ObjectId(book_id)})

#         if book is None:
#             return jsonify({"error": "Book not found"}), 404

#         # Convert ObjectId to string to avoid BSON format issues
#         book['_id'] = str(book['_id'])

#         # Return the JSON response
#         return jsonify(book)
#     except Exception as e:
#         return jsonify({"error": str(e)}), 500

# ============================================================================================


# ============================================================================================

# ============================================================================================

# Example model for books collection
# class Book:
#     def __init__(self, title, author, publisher, price, front_image, back_image):
#         self.title = title
#         self.author = author
#         self.publisher = publisher
#         self.price = price
#         self.front_image = front_image
#         self.back_image = back_image

# ============================================================================================


# ============================================================================================

# Example API route to retrieve all books
# @app.route('/books', methods=['GET'])
# def get_books():
#     try:
#         # Fetch all books from the 'books' collection
#         books_cursor = db['books'].find()

#         # Convert the cursor to a list of dictionaries
#         books_list = list(books_cursor)

#         # Optional: You can manually remove ObjectId to avoid BSON format issues
#         for book in books_list:
#             book['_id'] = str(book['_id'])  # Convert ObjectId to string

#         # Return the JSON response
#         return jsonify(books_list)
#     except Exception as e:
#         return jsonify({"error": str(e)}), 500

# ============================================================================================

# Example API route to add a new book
# @app.route('/books', methods=['POST'])
# def add_book():
    # books_collection = db.books  # Replace 'books' with your collection name

    # Sample data from request (assuming JSON input)
    # data = request.json

    # # for Book class we need this data:
    # title = data['title']
    # author = data['author']
    # publisher = data['publisher']
    # price = data['price']
    # front_image = data['front_image']
    # back_image = data['back_image']

    # # Create a new Book object
    # new_book = Book(title, author, publisher, price, front_image, back_image)

    # # Insert into MongoDB
    # result = books_collection.insert_one(new_book.__dict__)

    # return jsonify({'message': 'Book added successfully', 'id': str(result.inserted_id)})

    # -------------
    # Without Book Class we can do this:
    # Define the structure of the new book document
    # new_book = {
    #     "title": data["title"],
    #     "author": data["author"],
    #     "publisher": data["publisher"],
    #     "price": data["price"],
    #     "cover_image": data["cover_image"]
    # }
    
    # try:
    #     # Insert the new book document into the 'books' collection
    #     result = db['books'].insert_one(new_book)
        
    #     # Return the ID of the newly created book as a response
    #     return jsonify({"_id": str(result.inserted_id)}), 201
    
    # except Exception as e:
    #     # If there's an error, return the error message
    #     return jsonify({"error": str(e)}), 500

# ============================================================================================
