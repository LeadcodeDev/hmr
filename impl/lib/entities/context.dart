// abstract interface class ParametersContract {
//   Map<String, Object> get list;
//   T get<T>(String key);
// }
//
// abstract interface class RequestContract {
//   String get method;
//   Uri get uri;
// }
//
// abstract interface class ResponseContract {
//   dynamic body;
//   notFound({String? message});
// }
//
// abstract interface class Response implements ResponseContract {
//   dynamic body;
//
//   notFound({String? message}) {
//     shelf_request.notFound(message);
//   }
// }
//
// final class HttpContext {
//   ParametersContract params;
//   RequestContract request;
//   ResponseContract response = Response();
// }
