import 'package:flutter/material.dart';

import 'app_theme.dart';

class ActivityIconChoice {
  const ActivityIconChoice(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

abstract final class ActivityIconCatalog {
  static const fallbackId = 'task';

  // A deliberately human catalog rather than an exposed icon-font dump. Each
  // choice names something people commonly schedule, visit, care for, or do.
  static const choices = <ActivityIconChoice>[
    ActivityIconChoice('task', 'Task', Icons.check_circle_outline_rounded),
    ActivityIconChoice('goal', 'Goal', Icons.track_changes_rounded),
    ActivityIconChoice('calendar', 'Calendar', Icons.calendar_month_outlined),
    ActivityIconChoice('clock', 'Time', Icons.schedule_rounded),
    ActivityIconChoice(
      'reminder',
      'Reminder',
      Icons.notifications_none_rounded,
    ),
    ActivityIconChoice('deadline', 'Deadline', Icons.timer_outlined),
    ActivityIconChoice('repeat', 'Repeating', Icons.repeat_rounded),
    ActivityIconChoice('priority', 'Priority', Icons.flag_outlined),
    ActivityIconChoice('idea', 'Idea', Icons.lightbulb_outline_rounded),
    ActivityIconChoice('plan', 'Plan', Icons.event_note_outlined),
    ActivityIconChoice('work', 'Work', Icons.work_outline_rounded),
    ActivityIconChoice('office', 'Office', Icons.business_outlined),
    ActivityIconChoice('meeting', 'Meeting', Icons.groups_outlined),
    ActivityIconChoice(
      'presentation',
      'Presentation',
      Icons.co_present_outlined,
    ),
    ActivityIconChoice('client', 'Client', Icons.handshake_outlined),
    ActivityIconChoice('email', 'Email', Icons.mail_outline_rounded),
    ActivityIconChoice('call', 'Phone call', Icons.call_outlined),
    ActivityIconChoice('video_call', 'Video call', Icons.videocam_outlined),
    ActivityIconChoice('computer', 'Computer', Icons.computer_rounded),
    ActivityIconChoice('code', 'Coding', Icons.code_rounded),
    ActivityIconChoice('business', 'Business', Icons.storefront_outlined),
    ActivityIconChoice('money', 'Money', Icons.attach_money_rounded),
    ActivityIconChoice('bank', 'Bank', Icons.account_balance_outlined),
    ActivityIconChoice('savings', 'Savings', Icons.savings_outlined),
    ActivityIconChoice('budget', 'Budget', Icons.pie_chart_outline_rounded),
    ActivityIconChoice('bill', 'Bills', Icons.receipt_long_outlined),
    ActivityIconChoice('tax', 'Taxes', Icons.request_quote_outlined),
    ActivityIconChoice('shopping', 'Shopping', Icons.shopping_bag_outlined),
    ActivityIconChoice('groceries', 'Groceries', Icons.shopping_cart_outlined),
    ActivityIconChoice('delivery', 'Delivery', Icons.local_shipping_outlined),
    ActivityIconChoice('school', 'School', Icons.school_outlined),
    ActivityIconChoice('study', 'Study', Icons.menu_book_outlined),
    ActivityIconChoice('homework', 'Homework', Icons.assignment_outlined),
    ActivityIconChoice('exam', 'Exam', Icons.quiz_outlined),
    ActivityIconChoice('course', 'Course', Icons.auto_stories_outlined),
    ActivityIconChoice('library', 'Library', Icons.local_library_outlined),
    ActivityIconChoice('read', 'Reading', Icons.chrome_reader_mode_outlined),
    ActivityIconChoice('write', 'Writing', Icons.edit_note_rounded),
    ActivityIconChoice('language', 'Language', Icons.translate_rounded),
    ActivityIconChoice('research', 'Research', Icons.science_outlined),
    ActivityIconChoice('quran', 'Quran', Icons.book_outlined),
    ActivityIconChoice('masjid', 'Masjid', Icons.mosque_outlined),
    ActivityIconChoice('prayer', 'Prayer', Icons.self_improvement_rounded),
    ActivityIconChoice('fajr', 'Fajr', Icons.wb_twilight_outlined),
    ActivityIconChoice('sunrise', 'Sunrise', Icons.wb_sunny_outlined),
    ActivityIconChoice('charity', 'Charity', Icons.volunteer_activism_outlined),
    ActivityIconChoice('community', 'Community', Icons.diversity_3_outlined),
    ActivityIconChoice('reflection', 'Reflection', Icons.nights_stay_outlined),
    ActivityIconChoice('fasting', 'Fasting', Icons.no_food_outlined),
    ActivityIconChoice(
      'pilgrimage',
      'Pilgrimage',
      Icons.travel_explore_rounded,
    ),
    ActivityIconChoice('home', 'Home', Icons.home_outlined),
    ActivityIconChoice('clean', 'Cleaning', Icons.cleaning_services_outlined),
    ActivityIconChoice(
      'laundry',
      'Laundry',
      Icons.local_laundry_service_outlined,
    ),
    ActivityIconChoice('dishes', 'Dishes', Icons.soup_kitchen_outlined),
    ActivityIconChoice('room', 'Room', Icons.bedroom_parent_outlined),
    ActivityIconChoice('repair', 'Repair', Icons.home_repair_service_outlined),
    ActivityIconChoice('tools', 'Tools', Icons.handyman_outlined),
    ActivityIconChoice('garden', 'Gardening', Icons.yard_outlined),
    ActivityIconChoice('trash', 'Trash', Icons.delete_outline_rounded),
    ActivityIconChoice('move', 'Moving', Icons.open_with_rounded),
    ActivityIconChoice('cook', 'Cooking', Icons.restaurant_outlined),
    ActivityIconChoice(
      'breakfast',
      'Breakfast',
      Icons.breakfast_dining_outlined,
    ),
    ActivityIconChoice('lunch', 'Lunch', Icons.lunch_dining_outlined),
    ActivityIconChoice('dinner', 'Dinner', Icons.dinner_dining_outlined),
    ActivityIconChoice('coffee', 'Coffee', Icons.coffee_outlined),
    ActivityIconChoice('tea', 'Tea', Icons.emoji_food_beverage_outlined),
    ActivityIconChoice('water', 'Water', Icons.water_drop_outlined),
    ActivityIconChoice('restaurant', 'Restaurant', Icons.local_dining_outlined),
    ActivityIconChoice('bake', 'Baking', Icons.bakery_dining_outlined),
    ActivityIconChoice(
      'meal_plan',
      'Meal planning',
      Icons.ramen_dining_outlined,
    ),
    ActivityIconChoice('health', 'Health', Icons.favorite_outline_rounded),
    ActivityIconChoice('doctor', 'Doctor', Icons.medical_services_outlined),
    ActivityIconChoice('hospital', 'Hospital', Icons.local_hospital_outlined),
    ActivityIconChoice('dentist', 'Dentist', Icons.medication_outlined),
    ActivityIconChoice(
      'medicine',
      'Medicine',
      Icons.medication_liquid_outlined,
    ),
    ActivityIconChoice('pharmacy', 'Pharmacy', Icons.local_pharmacy_outlined),
    ActivityIconChoice('therapy', 'Therapy', Icons.psychology_outlined),
    ActivityIconChoice(
      'mental_health',
      'Mental health',
      Icons.psychology_alt_outlined,
    ),
    ActivityIconChoice('checkup', 'Checkup', Icons.health_and_safety_outlined),
    ActivityIconChoice('vaccine', 'Vaccine', Icons.vaccines_outlined),
    ActivityIconChoice('fitness', 'Fitness', Icons.fitness_center_rounded),
    ActivityIconChoice('workout', 'Workout', Icons.sports_gymnastics_outlined),
    ActivityIconChoice('run', 'Running', Icons.directions_run_rounded),
    ActivityIconChoice('walk', 'Walking', Icons.directions_walk_rounded),
    ActivityIconChoice('hike', 'Hiking', Icons.hiking_rounded),
    ActivityIconChoice('bike', 'Cycling', Icons.directions_bike_rounded),
    ActivityIconChoice('swim', 'Swimming', Icons.pool_outlined),
    ActivityIconChoice(
      'basketball',
      'Basketball',
      Icons.sports_basketball_outlined,
    ),
    ActivityIconChoice('football', 'Football', Icons.sports_football_outlined),
    ActivityIconChoice('soccer', 'Soccer', Icons.sports_soccer_outlined),
    ActivityIconChoice('baseball', 'Baseball', Icons.sports_baseball_outlined),
    ActivityIconChoice('tennis', 'Tennis', Icons.sports_tennis_outlined),
    ActivityIconChoice('golf', 'Golf', Icons.sports_golf_outlined),
    ActivityIconChoice('boxing', 'Boxing', Icons.sports_mma_outlined),
    ActivityIconChoice('yoga', 'Yoga', Icons.accessibility_new_rounded),
    ActivityIconChoice(
      'stretch',
      'Stretching',
      Icons.airline_seat_flat_rounded,
    ),
    ActivityIconChoice('weight', 'Weight', Icons.monitor_weight_outlined),
    ActivityIconChoice('sleep', 'Sleep', Icons.bedtime_outlined),
    ActivityIconChoice('nap', 'Nap', Icons.bed_outlined),
    ActivityIconChoice('morning', 'Morning routine', Icons.wb_sunny_rounded),
    ActivityIconChoice('night', 'Night routine', Icons.dark_mode_outlined),
    ActivityIconChoice('family', 'Family', Icons.family_restroom_outlined),
    ActivityIconChoice('friends', 'Friends', Icons.people_outline_rounded),
    ActivityIconChoice('person', 'Person', Icons.person_outline_rounded),
    ActivityIconChoice('children', 'Children', Icons.child_care_outlined),
    ActivityIconChoice('baby', 'Baby', Icons.child_friendly_outlined),
    ActivityIconChoice('birthday', 'Birthday', Icons.cake_outlined),
    ActivityIconChoice('wedding', 'Wedding', Icons.diamond_outlined),
    ActivityIconChoice('party', 'Party', Icons.celebration_outlined),
    ActivityIconChoice('gift', 'Gift', Icons.card_giftcard_outlined),
    ActivityIconChoice('contact', 'Contact', Icons.contacts_outlined),
    ActivityIconChoice('help', 'Helping', Icons.support_agent_outlined),
    ActivityIconChoice('cat', 'Cat', Icons.pets_rounded),
    ActivityIconChoice('dog', 'Dog', Icons.pets_outlined),
    ActivityIconChoice('pet', 'Pet care', Icons.cruelty_free_outlined),
    ActivityIconChoice('vet', 'Veterinarian', Icons.health_and_safety_rounded),
    ActivityIconChoice('feed_pet', 'Feed pet', Icons.food_bank_outlined),
    ActivityIconChoice('dog_walk', 'Walk dog', Icons.emoji_nature_outlined),
    ActivityIconChoice('zoo', 'Zoo', Icons.attractions_outlined),
    ActivityIconChoice('aquarium', 'Aquarium', Icons.water_outlined),
    ActivityIconChoice('farm', 'Farm', Icons.agriculture_outlined),
    ActivityIconChoice('horse', 'Horse riding', Icons.landscape_outlined),
    ActivityIconChoice('bird', 'Bird care', Icons.flutter_dash_rounded),
    ActivityIconChoice('travel', 'Travel', Icons.flight_takeoff_rounded),
    ActivityIconChoice('flight', 'Flight', Icons.flight_outlined),
    ActivityIconChoice('hotel', 'Hotel', Icons.hotel_outlined),
    ActivityIconChoice('vacation', 'Vacation', Icons.beach_access_outlined),
    ActivityIconChoice('trip', 'Trip', Icons.luggage_outlined),
    ActivityIconChoice('map', 'Map', Icons.map_outlined),
    ActivityIconChoice('location', 'Place', Icons.location_on_outlined),
    ActivityIconChoice('museum', 'Museum', Icons.museum_outlined),
    ActivityIconChoice('park', 'Park', Icons.park_outlined),
    ActivityIconChoice('camping', 'Camping', Icons.cabin_outlined),
    ActivityIconChoice('nature', 'Nature', Icons.forest_outlined),
    ActivityIconChoice('photo', 'Photography', Icons.photo_camera_outlined),
    ActivityIconChoice('sightseeing', 'Sightseeing', Icons.tour_outlined),
    ActivityIconChoice('car', 'Car', Icons.directions_car_outlined),
    ActivityIconChoice('drive', 'Driving', Icons.drive_eta_outlined),
    ActivityIconChoice('bus', 'Bus', Icons.directions_bus_outlined),
    ActivityIconChoice('train', 'Train', Icons.train_outlined),
    ActivityIconChoice('subway', 'Subway', Icons.subway_outlined),
    ActivityIconChoice('taxi', 'Taxi', Icons.local_taxi_outlined),
    ActivityIconChoice('commute', 'Commute', Icons.commute_outlined),
    ActivityIconChoice('gas', 'Fuel', Icons.local_gas_station_outlined),
    ActivityIconChoice('parking', 'Parking', Icons.local_parking_outlined),
    ActivityIconChoice('car_repair', 'Car repair', Icons.car_repair_outlined),
    ActivityIconChoice('music', 'Music', Icons.music_note_rounded),
    ActivityIconChoice('concert', 'Concert', Icons.queue_music_rounded),
    ActivityIconChoice('movie', 'Movie', Icons.movie_outlined),
    ActivityIconChoice('tv', 'Television', Icons.tv_outlined),
    ActivityIconChoice('game', 'Gaming', Icons.sports_esports_outlined),
    ActivityIconChoice('art', 'Art', Icons.palette_outlined),
    ActivityIconChoice('draw', 'Drawing', Icons.draw_outlined),
    ActivityIconChoice('craft', 'Crafts', Icons.content_cut_rounded),
    ActivityIconChoice('dance', 'Dancing', Icons.music_video_outlined),
    ActivityIconChoice('theater', 'Theater', Icons.theater_comedy_outlined),
    ActivityIconChoice('podcast', 'Podcast', Icons.podcasts_outlined),
    ActivityIconChoice('journal', 'Journal', Icons.auto_stories_rounded),
    ActivityIconChoice('meditate', 'Meditation', Icons.spa_outlined),
    ActivityIconChoice('haircut', 'Haircut', Icons.content_cut_outlined),
    ActivityIconChoice('spa', 'Spa', Icons.hot_tub_outlined),
    ActivityIconChoice(
      'skincare',
      'Skincare',
      Icons.face_retouching_natural_outlined,
    ),
    ActivityIconChoice('shower', 'Shower', Icons.shower_outlined),
    ActivityIconChoice('clothes', 'Clothes', Icons.checkroom_outlined),
    ActivityIconChoice(
      'appointment',
      'Appointment',
      Icons.event_available_outlined,
    ),
    ActivityIconChoice('errand', 'Errand', Icons.directions_outlined),
    ActivityIconChoice(
      'post_office',
      'Post office',
      Icons.local_post_office_outlined,
    ),
    ActivityIconChoice('package', 'Package', Icons.inventory_2_outlined),
    ActivityIconChoice('documents', 'Documents', Icons.description_outlined),
    ActivityIconChoice('print', 'Printing', Icons.print_outlined),
    ActivityIconChoice('upload', 'Upload', Icons.upload_file_outlined),
    ActivityIconChoice('download', 'Download', Icons.download_outlined),
    ActivityIconChoice('security', 'Security', Icons.security_outlined),
    ActivityIconChoice('password', 'Password', Icons.password_outlined),
    ActivityIconChoice('internet', 'Internet', Icons.language_rounded),
    ActivityIconChoice('phone', 'Phone', Icons.phone_android_outlined),
    ActivityIconChoice(
      'charge',
      'Charge device',
      Icons.battery_charging_full_rounded,
    ),
    ActivityIconChoice('weather', 'Weather', Icons.cloud_outlined),
    ActivityIconChoice('rain', 'Rain', Icons.water_drop_rounded),
    ActivityIconChoice('snow', 'Snow', Icons.ac_unit_rounded),
    ActivityIconChoice('beach', 'Beach', Icons.waves_rounded),
    ActivityIconChoice('event', 'Event', Icons.event_outlined),
    ActivityIconChoice('ticket', 'Tickets', Icons.confirmation_number_outlined),
    ActivityIconChoice(
      'reservation',
      'Reservation',
      Icons.book_online_outlined,
    ),
    ActivityIconChoice(
      'volunteer',
      'Volunteer',
      Icons.connect_without_contact_outlined,
    ),
    ActivityIconChoice('vote', 'Voting', Icons.how_to_vote_outlined),
    ActivityIconChoice('court', 'Court', Icons.gavel_outlined),
    ActivityIconChoice('police', 'Police', Icons.local_police_outlined),
    ActivityIconChoice('fire', 'Fire department', Icons.fire_truck_outlined),
    ActivityIconChoice('emergency', 'Emergency', Icons.emergency_outlined),
    ActivityIconChoice('celebrate', 'Celebrate', Icons.emoji_events_outlined),
    ActivityIconChoice('habit', 'Habit', Icons.loop_rounded),
    ActivityIconChoice('focus', 'Focus', Icons.center_focus_strong_rounded),
    ActivityIconChoice('break', 'Break', Icons.free_breakfast_outlined),
    ActivityIconChoice('outdoors', 'Outdoors', Icons.terrain_outlined),
    ActivityIconChoice('boat', 'Boat', Icons.directions_boat_outlined),
    ActivityIconChoice('fish', 'Fishing', Icons.set_meal_outlined),
    ActivityIconChoice('picnic', 'Picnic', Icons.deck_outlined),
    ActivityIconChoice('market', 'Market', Icons.local_mall_outlined),
    ActivityIconChoice(
      'barber',
      'Barber',
      Icons.face_retouching_natural_rounded,
    ),
  ];

  static ActivityIconChoice byId(String? id) => choices.firstWhere(
    (choice) => choice.id == id,
    orElse: () => choices.first,
  );

  static ActivityIconChoice guess(String text) {
    final value = text.toLowerCase();
    for (final choice in choices.skip(1)) {
      if (value.contains(choice.id.replaceAll('_', ' ')) ||
          value.contains(choice.label.toLowerCase())) {
        return choice;
      }
    }
    if (value.contains('salah') || value.contains('prayer')) {
      return byId('masjid');
    }
    if (value.contains('qur')) return byId('quran');
    if (value.contains('gym') || value.contains('exercise')) {
      return byId('workout');
    }
    if (value.contains('study') || value.contains('lesson')) {
      return byId('study');
    }
    return choices.first;
  }
}

class ActivityIcon extends StatelessWidget {
  const ActivityIcon({super.key, this.id, this.size = 20, this.color});

  final String? id;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(ActivityIconCatalog.byId(id).icon, size: size, color: color);
}

Future<String?> showActivityIconPicker(
  BuildContext context, {
  String? selectedId,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _ActivityIconPicker(selectedId: selectedId),
);

class _ActivityIconPicker extends StatefulWidget {
  const _ActivityIconPicker({this.selectedId});
  final String? selectedId;

  @override
  State<_ActivityIconPicker> createState() => _ActivityIconPickerState();
}

class _ActivityIconPickerState extends State<_ActivityIconPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = ActivityIconCatalog.choices
        .where(
          (choice) =>
              query.isEmpty ||
              choice.label.toLowerCase().contains(query) ||
              choice.id.replaceAll('_', ' ').contains(query),
        )
        .toList(growable: false);
    return FractionallySizedBox(
      heightFactor: .86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose an icon',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${ActivityIconCatalog.choices.length} common activities and places',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search icons',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                MediaQuery.viewPaddingOf(context).bottom + 18,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: .92,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final choice = visible[index];
                final selected = choice.id == widget.selectedId;
                return Material(
                  color: selected ? context.appSoftBlue : context.appRaised,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected
                          ? Theme.of(context).colorScheme.secondary
                          : context.appBorder,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, choice.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            choice.icon,
                            color: selected
                                ? Theme.of(context).colorScheme.secondary
                                : context.appText,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            choice.label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, height: 1.15),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
