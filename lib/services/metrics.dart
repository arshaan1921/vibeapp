class MetricsService {
  static int appOpens = 0;
  static int questionsAsked = 0;
  static int answersPosted = 0;

  static void incrementAppOpens() => appOpens++;
  static void incrementQuestionsAsked() => questionsAsked++;
  static void incrementAnswersPosted() => answersPosted++;
}
