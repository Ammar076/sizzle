const admin = require('firebase-admin');
const fs = require('fs');

// IMPORTANT: Download your service account key from Firebase Console -> Project Settings -> Service Accounts
// Rename it to 'serviceAccountKey.json' and place it in this scripts folder.
const serviceAccountPath = './serviceAccountKey.json';

if (!fs.existsSync(serviceAccountPath)) {
  console.error("Error: serviceAccountKey.json not found!");
  console.error("Please download it from Firebase Console > Project Settings > Service Accounts and place it in the scripts directory.");
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const recipes = [
  // BREAKFAST (4)
  {
    title: 'Foul Medames',
    description: 'A deeply flavorful Yemeni-style fava bean stew mashed with tomatoes, onions, cumin, and olive oil. Served bubbling hot with warm flatbread.',
    imageUrl: 'https://i.ytimg.com/vi/MPiW2aXgqo4/maxresdefault.jpg',
    category: 'Breakfast',
    prepTime: 10,
    cookTime: 15,
    feeds: 3,
    isFavorite: false
  },
  {
    title: 'Yemeni Shakshuka',
    description: 'A savory breakfast of eggs scrambled with diced tomatoes, onions, green chilies, and aromatic spices.',
    imageUrl: 'https://images.unsplash.com/photo-1590412200988-a436970781fa?w=500&q=80',
    category: 'Breakfast',
    prepTime: 10,
    cookTime: 10,
    feeds: 2,
    isFavorite: false
  },
  {
    title: 'Kibdah (Yemeni Liver)',
    description: 'Fresh lamb liver stir-fried with onions, tomatoes, and a robust blend of Yemeni spices. A traditional breakfast delicacy.',
    imageUrl: 'https://s3.amazonaws.com/sheba-yemeni-food/app/public/images/67/yemeni-kebda.JPG',
    category: 'Breakfast',
    prepTime: 15,
    cookTime: 10,
    feeds: 4,
    isFavorite: false
  },
  {
    title: 'Masoob',
    description: 'A rich and sweet banana bread pudding made from overripe bananas, ground flatbread, thick cream, nuts, and a heavy drizzle of Yemeni honey.',
    imageUrl: 'https://res.cloudinary.com/the-infatuation/image/upload/c_fill,w_640,ar_4:3,g_center,f_auto/images/Bab_Al_Yemen_Masoob_with_Cream_and_Honey_AleksandraBoruch_London-2_lqmuz8',
    category: 'Breakfast',
    prepTime: 10,
    cookTime: 5,
    feeds: 2,
    isFavorite: false
  },

  // LUNCH (4)
  {
    title: 'Mandi',
    description: 'The iconic Yemeni dish. Slow-roasted tender lamb served over incredibly fragrant, smoke-infused basmati rice.',
    imageUrl: 'https://falasteenifoodie.com/wp-content/uploads/2023/03/IMG_5690-2.jpg',
    category: 'Lunch',
    prepTime: 30,
    cookTime: 120,
    feeds: 6,
    isFavorite: false
  },
  {
    title: 'Zurbian',
    description: 'A rich, fragrant meat and rice dish hailing from Aden, cooked with potatoes, yogurt, fried onions, and warm spices.',
    imageUrl: 'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgAMYry8SCanP76O1qfPBJDbdvsX1FFVTN8ggpKoz0vTV-P7tSqPRB4avUUSySTzBgWKuz90D9AdbUWqNBxHuvkryfBHuIFLeoA37rwTOSZ2kAm2H8Rt6e8Xjn6JQH38pnSFLS0N6wdi1xe78nnUu62NZrPwSQJEajWCoF60g2FmMaH5fWxR0lm4AyDeXg/s1280/Cooking%20Adeni%20chicken%20Zurbian%20Biryani%20in%20an%20easy%20and%20tasty%20way.jpg',
    category: 'Lunch',
    prepTime: 25,
    cookTime: 90,
    feeds: 5,
    isFavorite: false
  },
  {
    title: 'Fahsa',
    description: 'A sizzling, intensely flavorful shredded lamb stew cooked in a stone pot and topped with a frothy dollop of whipped fenugreek (holba).',
    imageUrl: 'https://cso-yemen.org/wp-content/uploads/2024/06/yemeni_meat_stew_benefits.jpg',
    category: 'Lunch',
    prepTime: 20,
    cookTime: 120,
    feeds: 4,
    isFavorite: false
  },
  {
    title: 'Saltah',
    description: 'The national dish of Yemen. A hearty meat broth base mixed with root vegetables, rice, and salsa, topped with fenugreek froth and served bubbling hot.',
    imageUrl: 'https://i.ytimg.com/vi/h_N27Rh-ZDA/maxresdefault.jpg',
    category: 'Lunch',
    prepTime: 20,
    cookTime: 40,
    feeds: 3,
    isFavorite: false
  },

  // DINNER (4)
  {
    title: 'Bint Al-sahn',
    description: 'A traditional Yemeni honey cake made from layered flaky bread, baked until golden, and served warm with generous amounts of honey and black seeds.',
    imageUrl: 'images/Bint_Al-sahn.jpg',
    category: 'Dinner',
    prepTime: 40,
    cookTime: 30,
    feeds: 6,
    isFavorite: false
  },
  {
    title: 'Sayadiyah',
    description: 'A coastal Yemeni specialty featuring spiced fish served over aromatic brown rice caramelized with deeply roasted onions.',
    imageUrl: 'https://aqababylocals.com/wp-content/uploads/2022/04/1F2A0207-1.jpg',
    category: 'Dinner',
    prepTime: 20,
    cookTime: 45,
    feeds: 4,
    isFavorite: false
  },
  {
    title: 'Chicken Aqda',
    description: 'A thick, rich, and slightly spicy shredded chicken stew cooked down with tomatoes, garlic, coriander, and potatoes.',
    imageUrl: 'https://noilucky.com/wp-content/uploads/2023/10/rotisserie-kadai-chicken-1024x538.webp',
    category: 'Dinner',
    prepTime: 15,
    cookTime: 60,
    feeds: 4,
    isFavorite: false
  },
  {
    title: 'Shafout',
    description: 'A refreshing and tangy layered dish made of savory sourdough flatbread (lahoh) completely soaked in a cool yogurt sauce blended with mint and garlic.',
    imageUrl: 'https://i.ytimg.com/vi/DkolTBwwJnc/maxresdefault.jpg',
    category: 'Dinner',
    prepTime: 20,
    cookTime: 0,
    feeds: 4,
    isFavorite: false
  }
];

async function seedDatabase() {
  const collectionRef = db.collection('recipes');

  console.log('Clearing existing recipes...');
  try {
    const snapshot = await collectionRef.get();
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    console.log('Cleared existing recipes.');
  } catch (error) {
    console.error('Error clearing database:', error);
  }

  console.log('Seeding database with recipes...');

  try {
    for (const recipe of recipes) {
      const docRef = await collectionRef.add(recipe);
      console.log(`Added recipe: ${recipe.title} (ID: ${docRef.id})`);
    }
    console.log('Database seeded successfully!');
  } catch (error) {
    console.error('Error seeding database:', error);
  } finally {
    process.exit(0);
  }
}

seedDatabase();
