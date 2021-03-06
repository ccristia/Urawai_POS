import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:urawai_pos/core/Models/products.dart';
import 'package:urawai_pos/core/Models/transaction.dart';
import 'package:urawai_pos/core/Models/users.dart';

class FirestoreServices {
  Firestore _firestore = Firestore.instance;

  // get All Documents
  Stream<QuerySnapshot> getAllDocuments(String shopName) {
    var result = _firestore.collection(shopName).snapshots();

    return result;
  }

  Future<List<Product>> getProducts(String shopName) async {
    List<Product> products = [];

    QuerySnapshot result = await _firestore
        .collection(shopName + '_products')
        .orderBy('productName', descending: false)
        .getDocuments();

    for (var data in result.documents)
      products.add(Product(
          id: data['id'],
          category: data['category'],
          discount: data['discount'].toDouble(),
          image: data['photo_url'],
          isRecommended: data['isPopuler'],
          name: data['productName'],
          price: data['price']));

    return products;
  }

  Future<QuerySnapshot> getDocumentLength(String shopName) {
    return _firestore.collection(shopName).getDocuments();
  }

  //*===================================================
  //* ==================[TRANSACTION SECTION]===========
  //*===================================================

  //* Post Transaction
  Future<void> postTransaction(
      String shopName, TransactionOrder transaction) async {
    try {
      await _firestore.collection(shopName).document(transaction.id).setData({
        'id': transaction.id,
        'cashierName': transaction.cashierName,
        'orderDate': transaction.date,
        'referenceOrder': transaction.referenceOrder,
        'discount': transaction.discount,
        'subtotal': transaction.subtotal,
        'grandTotal': transaction.grandTotal,
        'paymentStatus': transaction.paymentStatus.toString(),
        'paymentType': transaction.paymentType.toString(),
        'tender': transaction.tender,
        'vat': transaction.vat,
        'change': transaction.paymentType == PaymentType.CASH &&
                transaction.paymentStatus != PaymentStatus.VOID
            ? transaction.tender - transaction.grandTotal
            : 0,
        'orderlist': transaction.itemList.map((data) => data.toJson()).toList(),
      });
    } catch (e) {
      print(e.toString());
    }
  }

  //* get All Documents exclude Void Trnsaction
  Future<List<TransactionOrder>> getAllDocumentsWithoutVOID(
      String shopName) async {
    List<TransactionOrder> transactions = [];
    var snapshot = await _firestore.collection(shopName).getDocuments();
    for (var data in snapshot.documents) {
      if (data['paymentStatus'] != 'PaymentStatus.VOID')
        transactions.add(TransactionOrder.fromJson(data.data));
    }

    return transactions;
  }

  Future<List<TransactionOrder>> getAllTransactionOrder(String shopName) async {
    List<TransactionOrder> transactions = [];
    var documents = await _firestore
        .collection(shopName)
        .orderBy('orderDate', descending: true)
        .getDocuments();
    for (var data in documents.documents)
      transactions.add(TransactionOrder.fromJson(data.data));

    return transactions;
  }

  // get Document by selected Date
  Future<List<TransactionOrder>> getDocumentByDate(
      String shopName, List<DateTime> date,
      {bool includeVoid = true}) async {
    List<TransactionOrder> transactions = [];
    var snapshot = await _firestore
        .collection(shopName)
        .orderBy('orderDate')
        .getDocuments();

    //pick 1 date
    if (date.length == 1) {
      for (var transaction in snapshot.documents) {
        var formatedDate = DateFormat("yMd")
            .format((transaction['orderDate'] as Timestamp).toDate());
        if (includeVoid == true) {
          if (formatedDate == DateFormat("yMd").format(date[0]))
            transactions.add(TransactionOrder.fromJson(transaction.data));
        } else if (includeVoid == false) {
          if (formatedDate == DateFormat("yMd").format(date[0]) &&
              transaction['paymentStatus'] != 'PaymentStatus.VOID')
            transactions.add(TransactionOrder.fromJson(transaction.data));
        }
      }
      //pick 2 dates
    } else if (date.length == 2) {
      for (var transaction in snapshot.documents) {
        DateTime orderDate = (transaction['orderDate'] as Timestamp).toDate();
        var formatedDate = DateFormat("yMd")
            .format((transaction['orderDate'] as Timestamp).toDate());
        if (includeVoid == true) {
          if (formatedDate == DateFormat("yMd").format(date[0]) ||
              formatedDate == DateFormat("yMd").format(date[1]) ||
              (orderDate.isAfter(date[0]) && orderDate.isBefore(date[1])))
            transactions.add(TransactionOrder.fromJson(transaction.data));
        } else if (includeVoid == false) {
          if (transaction['paymentStatus'] != 'PaymentStatus.VOID') {
            if (formatedDate == DateFormat("yMd").format(date[0]) ||
                formatedDate == DateFormat("yMd").format(date[1]) ||
                (orderDate.isAfter(date[0]) && orderDate.isBefore(date[1])))
              transactions.add(TransactionOrder.fromJson(transaction.data));
          }
        }
      }
    }

    return transactions;
  }

  // get Document by Document ID
  Future<DocumentSnapshot> getDocumentByID(
    String shopName,
    String id,
  ) {
    Future<DocumentSnapshot> result =
        _firestore.collection(shopName).document(id).get();

    return result;
  }

  // get Document by Product Name
  Future<List<Product>> getDocumentByProductName(
    String shopName,
    String query,
  ) async {
    List<Product> result = [];

    _firestore
        .collection(shopName + '_products')
        .reference()
        .snapshots()
        .forEach((data) {
      data.documents.forEach((product) {
        if (product.data['productName']
            .toString()
            .toUpperCase()
            .contains(query.toUpperCase())) {
          result.add(Product(
              id: product.data['id'],
              name: product.data['productName'],
              price: product.data['price'],
              category: product.data['category'],
              image: product.data['photo_url'],
              discount: product.data['discount'].toDouble(),
              isRecommended: product.data['isPopuler']));
        }
      });
    });

    return result;
  }

  Future<Users> currentUser(String id) async {
    var snapshot = await _firestore
        .collection('Users')
        .where('id', isEqualTo: id)
        .getDocuments();
    var users =
        snapshot.documents.map((documents) => Users.fromJson(documents.data));
    var currentUser = users.firstWhere((element) => element.id == id);

    return currentUser;
  }

  //* ===================================================
  //* ==================[DELETE SECTION]=================
  //* ===================================================

  //delete transaction by ID
  Future<void> deleteTransaction(String shopName, String id) async {
    await _firestore.collection(shopName).document(id).delete();
  }

  //delete Product by ID
  Future<void> deleteProduct(String shopName, String productId) async {
    await _firestore
        .collection(shopName + '_products')
        .document(productId)
        .delete();
  }

  //===================================================
  // ==================[USERS SECTION]=================
  //===================================================

  Future createUser(Users user) async {
    try {
      await _firestore
          .collection('Users')
          .document(user.id)
          .setData(user.toJson());
    } catch (e) {
      return e.message;
    }
  }

  Future<Users> getUser(String id) async {
    var snapshot = await _firestore.collection('Users').document(id).get();
    var currentUser = Users.fromJson(snapshot.data);
    return currentUser;
  }
}
